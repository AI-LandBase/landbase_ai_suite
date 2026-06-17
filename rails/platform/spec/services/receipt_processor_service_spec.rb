require "rails_helper"

RSpec.describe ReceiptProcessorService do
  let(:client) { create(:client, code: "test_client") }
  let(:image_file) do
    path = Rails.root.join("spec/fixtures/files/test_receipt.jpg")
    ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(path),
      filename: "test_receipt.jpg",
      type: "image/jpeg"
    )
  end

  let(:valid_response_json) do
    {
      is_receipt: true,
      receipt_date: "2026-03-01",
      vendor_name: "マックスバリュ やんばる店",
      total_amount: 2160,
      tax_amount: 160,
      has_invoice_number: true,
      invoice_registration_number: "T9876543210123",
      transactions: [
        {
          transaction_no: 1,
          date: "2026-03-01",
          debit_account: "仕入高",
          debit_sub_account: "",
          debit_department: "",
          debit_partner: "マックスバリュ やんばる店",
          debit_tax_category: "課税仕入8%（軽減・インボイス）",
          debit_invoice: "T9876543210123",
          debit_amount: 2160,
          credit_account: "現金",
          credit_sub_account: "",
          credit_department: "",
          credit_partner: "",
          credit_tax_category: "",
          credit_invoice: "",
          credit_amount: 2160,
          description: "マックスバリュ やんばる店 食材仕入",
          tag: "receipt",
          memo: "",
          status: "ok"
        }
      ],
      summary: {
        total_transactions: 1,
        total_amount: 2160,
        review_required_count: 0,
        accounts_breakdown: { "仕入高" => 2160 }
      }
    }.to_json
  end

  let(:mock_response) do
    double("Response",
      stop_reason: "end_turn",
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
    it "正常に画像を処理し仕訳データを返すこと" do
      service = described_class.new(image: image_file, client_code: client.code)

      result = service.call

      expect(result.success?).to be true
      expect(result.reason).to be_nil
      expect(result.data[:is_receipt]).to be true
      expect(result.data[:receipt_date]).to eq("2026-03-01")
      expect(result.data[:vendor_name]).to eq("マックスバリュ やんばる店")
      expect(result.data[:total_amount]).to eq(2160)
      expect(result.data[:transactions]).to be_an(Array)
      expect(result.data[:transactions].first[:debit_account]).to eq("仕入高")
      expect(result.data[:transactions].first[:credit_account]).to eq("現金")
      expect(result.data[:summary][:total_transactions]).to eq(1)
    end

    it "成功時はretryable?がfalseであること" do
      service = described_class.new(image: image_file, client_code: client.code)
      result = service.call
      expect(result.retryable?).to be false
    end

    it "AccountMasterのマッチ情報をプロンプトに含めること" do
      create(:account_master,
        client: client,
        source_type: "receipt",
        merchant_keyword: "マックスバリュ",
        account_category: "仕入高",
        confidence_score: 95
      )

      service = described_class.new(image: image_file, client_code: client.code)

      messages = mock_client.messages
      expect(messages).to receive(:create).with(
        hash_including(messages: [
          hash_including(content: array_including(
            hash_including(type: "text", text: include("マックスバリュ"))
          ))
        ])
      ).and_return(mock_response)

      service.call
    end

    it "Claude Vision APIに画像データを送信すること" do
      service = described_class.new(image: image_file, client_code: client.code)

      messages = mock_client.messages
      expect(messages).to receive(:create).with(
        hash_including(messages: [
          hash_including(content: array_including(
            hash_including(type: "image", source: hash_including(type: "base64", media_type: "image/jpeg"))
          ))
        ])
      ).and_return(mock_response)

      service.call
    end

    context "非領収書画像の場合" do
      let(:not_receipt_response_json) do
        { is_receipt: false }.to_json
      end

      let(:mock_response) do
        double("Response",
          stop_reason: "end_turn",
          content: [
            double("Content", type: "text", text: not_receipt_response_json)
          ]
        )
      end

      it "reason: :non_receiptの失敗Resultを返すこと" do
        service = described_class.new(image: image_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:non_receipt)
        expect(result.error).to eq("領収書として認識できません")
        expect(result.retryable?).to be false
      end
    end

    context "非対応画像フォーマットの場合" do
      let(:image_file) do
        tempfile = Tempfile.new(["test", ".avi"])
        tempfile.binmode
        tempfile.write("RIFF\x00\x00\x00\x00AVI ")
        tempfile.rewind
        ActionDispatch::Http::UploadedFile.new(
          tempfile: tempfile,
          filename: "test.avi",
          type: "video/avi"
        )
      end

      it "reason: :unsupported_formatの失敗Resultを返すこと" do
        service = described_class.new(image: image_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:unsupported_format)
        expect(result.error).to eq("対応していない画像フォーマットです")
        expect(result.retryable?).to be false
      end

      it "APIを呼び出さないこと" do
        service = described_class.new(image: image_file, client_code: client.code)
        messages = mock_client.messages

        expect(messages).not_to receive(:create)

        service.call
      end
    end

    context "画像フォーマット判定" do
      def build_upload(binary, filename, content_type)
        tempfile = Tempfile.new(["test", File.extname(filename)])
        tempfile.binmode
        tempfile.write(binary)
        tempfile.rewind
        ActionDispatch::Http::UploadedFile.new(
          tempfile: tempfile,
          filename: filename,
          type: content_type
        )
      end

      it "JPEG画像を正しく判定すること" do
        jpeg_binary = "\xFF\xD8\xFF\xE0" + "\x00" * 100
        upload = build_upload(jpeg_binary, "test.jpg", "image/jpeg")
        service = described_class.new(image: upload, client_code: client.code)

        messages = mock_client.messages
        expect(messages).to receive(:create).with(
          hash_including(messages: [
            hash_including(content: array_including(
              hash_including(source: hash_including(media_type: "image/jpeg"))
            ))
          ])
        ).and_return(mock_response)

        service.call
      end

      it "PNG画像を正しく判定すること" do
        png_binary = "\x89PNG\r\n\x1A\n" + "\x00" * 100
        upload = build_upload(png_binary, "test.png", "image/png")
        service = described_class.new(image: upload, client_code: client.code)

        messages = mock_client.messages
        expect(messages).to receive(:create).with(
          hash_including(messages: [
            hash_including(content: array_including(
              hash_including(source: hash_including(media_type: "image/png"))
            ))
          ])
        ).and_return(mock_response)

        service.call
      end

      it "WebP画像を正しく判定すること" do
        webp_binary = "RIFF\x00\x00\x00\x00WEBP" + "\x00" * 100
        upload = build_upload(webp_binary, "test.webp", "image/webp")
        service = described_class.new(image: upload, client_code: client.code)

        messages = mock_client.messages
        expect(messages).to receive(:create).with(
          hash_including(messages: [
            hash_including(content: array_including(
              hash_including(source: hash_including(media_type: "image/webp"))
            ))
          ])
        ).and_return(mock_response)

        service.call
      end

      it "RIFF形式でもWebP以外（AVI等）は非対応と判定すること" do
        avi_binary = "RIFF\x00\x00\x00\x00AVI " + "\x00" * 100
        upload = build_upload(avi_binary, "test.avi", "video/avi")
        service = described_class.new(image: upload, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:unsupported_format)
      end

      it "ランダムバイナリは非対応と判定すること" do
        random_binary = SecureRandom.random_bytes(100)
        upload = build_upload(random_binary, "test.bin", "application/octet-stream")
        service = described_class.new(image: upload, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:unsupported_format)
      end
    end

    context "JSONがコードブロックで囲まれている場合" do
      let(:mock_response) do
        double("Response",
          stop_reason: "end_turn",
          content: [
            double("Content", type: "text", text: "```json\n#{valid_response_json}\n```")
          ]
        )
      end

      it "正しくパースできること" do
        service = described_class.new(image: image_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be true
        expect(result.data[:transactions]).to be_present
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

      it "reason: :api_errorの失敗Resultを返すこと" do
        service = described_class.new(image: image_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:api_error)
        expect(result.error).to include("Anthropic API エラー")
        expect(result.retryable?).to be true
      end
    end

    context "不正なJSONが返された場合" do
      let(:mock_response) do
        double("Response",
          stop_reason: "end_turn",
          content: [
            double("Content", type: "text", text: "invalid json {{{")
          ]
        )
      end

      it "reason: :parse_errorの失敗Resultを返すこと" do
        service = described_class.new(image: image_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:parse_error)
        expect(result.error).to include("JSON パースエラー")
      end
    end

    context "ANTHROPIC_API_KEYが未設定の場合" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)
        allow(ENV).to receive(:fetch).and_call_original
      end

      it "reason: :config_errorの失敗Resultを返すこと" do
        service = described_class.new(image: image_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:config_error)
        expect(result.error).to include("ANTHROPIC_API_KEY")
      end
    end

    context "max_tokensで切り詰められた場合" do
      let(:mock_response) do
        double("Response",
          stop_reason: "max_tokens",
          content: [
            double("Content", type: "text", text: '{"incomplete": true}')
          ]
        )
      end

      it "reason: :api_errorの失敗Resultを返すこと" do
        service = described_class.new(image: image_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:api_error)
        expect(result.error).to include("max_tokens")
      end
    end

    context "ActiveStorage::FileNotFoundError が発生した場合" do
      it "file_not_found reasonで失敗し、retryableでないこと" do
        broken_image = double("BrokenAttachment")
        allow(broken_image).to receive(:respond_to?).with(:download).and_return(true)
        allow(broken_image).to receive(:respond_to?).with(:read).and_return(false)
        allow(broken_image).to receive(:download).and_raise(
          ActiveStorage::FileNotFoundError, "missing file"
        )

        service = described_class.new(image: broken_image, client_code: client.code)
        result = service.call

        expect(result.success?).to be false
        expect(result.reason).to eq(:file_not_found)
        expect(result.error).to include("画像ファイルが見つかりません")
        expect(result.retryable?).to be false
      end
    end

    context "ストレージ系エラー (issue#299)" do
      it "EACCES等のシステムエラーは storage_error で非リトライ、クラス名を漏らさないこと" do
        broken_image = double("BrokenAttachment")
        allow(broken_image).to receive(:download).and_raise(Errno::EACCES, "Permission denied")

        result = described_class.new(image: broken_image, client_code: client.code).call

        expect(result.success?).to be false
        expect(result.reason).to eq(:storage_error)
        expect(result.retryable?).to be false
        expect(result.error).not_to include("Errno")
        expect(result.error).to include("読み込めませんでした")
      end

      it "FileNotFoundError のメッセージが空でもクラス名を漏らさないこと" do
        broken_image = double("BrokenAttachment")
        allow(broken_image).to receive(:download).and_raise(ActiveStorage::FileNotFoundError)

        result = described_class.new(image: broken_image, client_code: client.code).call

        expect(result.reason).to eq(:file_not_found)
        expect(result.error).not_to include("ActiveStorage")
        expect(result.error).to include("画像ファイルが見つかりません")
      end

      it "FileNotFoundError は元例外を WARN ログに残すこと (issue#327)" do
        broken_image = double("BrokenAttachment")
        allow(broken_image).to receive(:download).and_raise(ActiveStorage::FileNotFoundError)
        expect(Rails.logger).to receive(:warn).with(/ReceiptProcessorService.*ActiveStorage::FileNotFoundError/)

        described_class.new(image: broken_image, client_code: client.code).call
      end

      it "システムエラーは元例外を ERROR ログに残すこと (issue#327)" do
        broken_image = double("BrokenAttachment")
        allow(broken_image).to receive(:download).and_raise(Errno::ENOSPC, "No space left on device")
        expect(Rails.logger).to receive(:error).with(/ReceiptProcessorService.*Errno::ENOSPC/)

        described_class.new(image: broken_image, client_code: client.code).call
      end
    end
  end
end
