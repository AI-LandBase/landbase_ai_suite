require "rails_helper"

RSpec.describe CleaningPhotoJudgeService do
  let(:photo) do
    path = Rails.root.join("spec/fixtures/files/test_image.jpg")
    ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(path),
      filename: "test_image.jpg",
      type: "image/jpeg"
    )
  end

  let(:service) do
    described_class.new(
      photos: [photo],
      task: "ベッドメイキング",
      description: "シーツを交換し、枕を配置する",
      checkpoint: "シーツにしわがないこと"
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
    context "API が OK を返す場合" do
      let(:mock_response) do
        double("Response",
          content: [double("Content", type: "text", text: '{"result":"ok","feedback":"清掃状態は良好です。"}')]
        )
      end

      it "OK 判定を返すこと" do
        result = service.call
        expect(result.success?).to be true
        expect(result.result).to eq("ok")
        expect(result.feedback).to eq("清掃状態は良好です。")
      end
    end

    context "API が NG を返す場合" do
      let(:mock_response) do
        double("Response",
          content: [double("Content", type: "text", text: '{"result":"ng","feedback":"シーツにしわが残っています。"}')]
        )
      end

      it "NG 判定を返すこと" do
        result = service.call
        expect(result.success?).to be true
        expect(result.result).to eq("ng")
        expect(result.feedback).to include("しわ")
      end
    end

    context "API エラーの場合" do
      let(:mock_response) { nil }

      before do
        mock_messages = double("Messages")
        allow(mock_messages).to receive(:create).and_raise(StandardError.new("API connection failed"))
        mock_client_err = double("Anthropic::Client", messages: mock_messages)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client_err)
      end

      it "エラーを返すこと" do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("エラー")
      end
    end

    context "JSON パースエラーの場合" do
      let(:mock_response) do
        double("Response",
          content: [double("Content", type: "text", text: "これはJSONではありません")]
        )
      end

      it "エラーを返すこと" do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("パースエラー")
      end
    end
  end
end
