require "rails_helper"

RSpec.describe CleaningManualGeneratorService do
  let(:image_file) do
    path = Rails.root.join("spec/fixtures/files/test_image.jpg")
    ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(path),
      filename: "test_image.jpg",
      type: "image/jpeg"
    )
  end

  let(:valid_response_json) do
    {
      property_name: "テスト施設",
      room_type: "スタンダード",
      generated_at: Time.current.iso8601,
      areas: [
        {
          area_name: "寝室",
          reference_images: ["test_image.jpg"],
          cleaning_steps: [
            {
              order: 1,
              task: "ベッドメイキング",
              description: "シーツを交換し、枕を配置する",
              checkpoint: "シーツにしわがないこと",
              estimated_minutes: 10
            }
          ],
          quality_standards: ["ベッドカバーが均一に整えられている"]
        }
      ],
      supplies_needed: ["マイクロファイバークロス"],
      total_estimated_minutes: 10
    }.to_json
  end

  let(:mock_response) do
    double("Response",
      content: [
        double("Content", type: "text", text: valid_response_json)
      ]
    )
  end

  let(:mock_client) do
    client = double("Anthropic::Client")
    messages = double("Messages")
    allow(client).to receive(:messages).and_return(messages)
    allow(messages).to receive(:create).and_return(mock_response)
    client
  end

  before do
    allow(Anthropic::Client).to receive(:new).and_return(mock_client)
  end

  describe "#call" do
    it "正常にマニュアルを生成できること" do
      service = described_class.new(
        images: [image_file],
        property_name: "テスト施設",
        room_type: "スタンダード"
      )

      result = service.call

      expect(result.success?).to be true
      expect(result.data[:property_name]).to eq("テスト施設")
      expect(result.data[:room_type]).to eq("スタンダード")
      expect(result.data[:areas]).to be_an(Array)
      expect(result.data[:areas].first[:area_name]).to eq("寝室")
    end

    it "ラベル付きで生成できること" do
      service = described_class.new(
        images: [image_file],
        property_name: "テスト施設",
        room_type: "スタンダード",
        labels: ["寝室画像"]
      )

      result = service.call
      expect(result.success?).to be true
    end

    it "画像読み取りのシステムエラー(EACCES等)は storage_error で非リトライ、クラス名を漏らさないこと (issue#299)" do
      service = described_class.new(
        images: [image_file],
        property_name: "テスト施設",
        room_type: "スタンダード"
      )
      allow(service).to receive(:resize_image).and_raise(Errno::EACCES, "Permission denied")

      result = service.call

      expect(result.success?).to be false
      expect(result.reason).to eq(:storage_error)
      expect(result.retryable?).to be false
      expect(result.error).not_to include("Errno")
      expect(result.error).to include("読み込めませんでした")
    end

    context "JSONがコードブロックで囲まれている場合" do
      let(:mock_response) do
        double("Response",
          content: [
            double("Content", type: "text", text: "```json\n#{valid_response_json}\n```")
          ]
        )
      end

      it "正しくパースできること" do
        service = described_class.new(
          images: [image_file],
          property_name: "テスト施設",
          room_type: "スタンダード"
        )

        result = service.call
        expect(result.success?).to be true
        expect(result.data[:areas]).to be_present
      end
    end

    context "JSONがコードブロックなしでテキストに埋まっている場合" do
      let(:mock_response) do
        double("Response",
          content: [
            double("Content", type: "text", text: "以下がマニュアルです。\n#{valid_response_json}\n何かご質問があれば。")
          ]
        )
      end

      it "JSON部分を抽出してパースできること" do
        service = described_class.new(
          images: [image_file],
          property_name: "テスト施設",
          room_type: "スタンダード"
        )

        result = service.call
        expect(result.success?).to be true
        expect(result.data[:areas]).to be_present
      end
    end

    context "APIエラーが発生した場合" do
      before do
        messages = double("Messages")
        allow(mock_client).to receive(:messages).and_return(messages)
        allow(messages).to receive(:create).and_raise(
          Anthropic::Errors::AuthenticationError.new(
            url: "https://api.anthropic.com/v1/messages",
            status: 401,
            headers: {},
            body: { error: { message: "API key invalid" } },
            request: double("Request"),
            response: double("Response")
          )
        )
      end

      it "エラーを返すこと" do
        service = described_class.new(
          images: [image_file],
          property_name: "テスト施設",
          room_type: "スタンダード"
        )

        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("Anthropic API エラー")
      end
    end

    context "不正なJSONが返された場合" do
      let(:mock_response) do
        double("Response",
          content: [
            double("Content", type: "text", text: "invalid json {{{")
          ]
        )
      end

      it "エラーを返すこと" do
        service = described_class.new(
          images: [image_file],
          property_name: "テスト施設",
          room_type: "スタンダード"
        )

        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("JSON パースエラー")
      end
    end
  end

  describe "バッチ処理" do
    it "20枚以下の場合はバッチ分割しないこと" do
      images = Array.new(5) { image_file }
      service = described_class.new(
        images: images,
        property_name: "テスト施設",
        room_type: "スタンダード"
      )

      messages = mock_client.messages
      expect(messages).to receive(:create).once.and_return(mock_response)

      service.call
    end

    it "20枚超の場合はバッチ分割すること" do
      images = Array.new(25) { image_file }
      service = described_class.new(
        images: images,
        property_name: "テスト施設",
        room_type: "スタンダード"
      )

      messages = mock_client.messages
      expect(messages).to receive(:create).twice.and_return(mock_response)

      result = service.call
      expect(result.success?).to be true
    end
  end
end
