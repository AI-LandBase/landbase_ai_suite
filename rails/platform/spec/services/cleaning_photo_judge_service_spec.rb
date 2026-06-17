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
    context "ANTHROPIC_API_KEY が未設定の場合" do
      let(:mock_response) { nil }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)
      end

      it "エラーを返すこと" do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("ANTHROPIC_API_KEY")
      end
    end

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
        allow(mock_messages).to receive(:create).and_raise(
          Anthropic::Errors::APIError.new(
            url: "https://api.anthropic.com/v1/messages",
            status: 500,
            headers: {},
            body: { error: { message: "API connection failed" } },
            request: double("Request"),
            response: double("Response")
          )
        )
        mock_client_err = double("Anthropic::Client", messages: mock_messages)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client_err)
      end

      it "エラーを返すこと" do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("エラー")
      end
    end

    context "AI が不正な result 値を返す場合" do
      let(:mock_response) do
        double("Response",
          content: [double("Content", type: "text", text: '{"result":"pass","feedback":"良い"}')]
        )
      end

      it "エラーを返すこと" do
        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("不正")
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

    context "画像読み取りのストレージ系エラー (issue#325)" do
      let(:mock_response) { nil }

      # STORAGE_SYSTEM_ERRORS の全メンバーを一律にマスクすることを検証する。
      # リストに Errno を追加した場合も自動でカバーされる。
      StorageErrorHandling::STORAGE_SYSTEM_ERRORS.each do |error_class|
        it "#{error_class} は失敗として返し、クラス名を漏らさないこと" do
          allow(service).to receive(:resize_image).and_raise(error_class)

          result = service.call

          expect(result.success?).to be false
          expect(result.error).not_to include("Errno")
          expect(result.error).not_to include(error_class.name)
          expect(result.error).to include("読み込めませんでした")
        end
      end

      it "元例外を ERROR ログに残すこと (issue#327)" do
        allow(service).to receive(:resize_image).and_raise(Errno::ENOSPC, "No space left on device")
        expect(Rails.logger).to receive(:error).with(/CleaningPhotoJudgeService.*Errno::ENOSPC/)

        service.call
      end
    end
  end
end
