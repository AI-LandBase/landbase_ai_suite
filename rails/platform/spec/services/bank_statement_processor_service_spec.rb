require "rails_helper"

RSpec.describe BankStatementProcessorService do
  let(:client) { create(:client, code: "test_client") }
  let(:pdf_file) do
    path = Rails.root.join("spec/fixtures/files/test_statement.pdf")
    ActionDispatch::Http::UploadedFile.new(
      tempfile: File.open(path),
      filename: "test_statement.pdf",
      type: "application/pdf"
    )
  end

  let(:valid_response_json) do
    {
      statement_period: "2026年1月",
      bank_name: "琉球銀行",
      branch_name: "名護支店",
      generated_at: Time.current.iso8601,
      transactions: [
        {
          transaction_no: 1,
          date: "2026-01-05",
          debit_account: "水道光熱費",
          debit_sub_account: "",
          debit_department: "",
          debit_partner: "ｵｷﾅﾜﾃﾞﾝﾘﾖｸ",
          debit_tax_category: "課税仕入10%（非インボイス）",
          debit_invoice: "",
          debit_amount: 45000,
          credit_account: "普通預金",
          credit_sub_account: "琉球銀行",
          credit_department: "",
          credit_partner: "",
          credit_tax_category: "",
          credit_invoice: "",
          credit_amount: 45000,
          description: "ﾃﾞﾝｷﾘﾖｳ ｵｷﾅﾜﾃﾞﾝﾘﾖｸ",
          tag: "bank",
          memo: "",
          status: "ok"
        }
      ],
      summary: {
        total_transactions: 1,
        total_withdrawals: 45000,
        total_deposits: 0,
        review_required_count: 0,
        accounts_breakdown: { "水道光熱費" => 45000 }
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

  let(:mock_pdf_pages) { [ double("Page1") ] }
  let(:mock_combine_pdf) { double("CombinePDF", pages: mock_pdf_pages) }

  before do
    allow(Anthropic::Client).to receive(:new).and_return(mock_client)
    allow(CombinePDF).to receive(:parse).and_return(mock_combine_pdf)
  end

  describe "#call" do
    it "正常にPDFを処理し仕訳データを返すこと" do
      service = described_class.new(pdf: pdf_file, client_code: client.code)

      result = service.call

      expect(result.success?).to be true
      expect(result.data[:statement_period]).to eq("2026年1月")
      expect(result.data[:bank_name]).to eq("琉球銀行")
      expect(result.data[:branch_name]).to eq("名護支店")
      expect(result.data[:transactions]).to be_an(Array)
      expect(result.data[:transactions].first[:debit_account]).to eq("水道光熱費")
      expect(result.data[:transactions].first[:credit_account]).to eq("普通預金")
      expect(result.data[:summary][:total_transactions]).to eq(1)
      expect(result.data[:summary][:total_withdrawals]).to eq(45000)
    end

    it "AccountMasterのマッチ情報をプロンプトに含めること" do
      create(:account_master,
        client: client,
        source_type: "bank",
        merchant_keyword: "特定取引先",
        account_category: "地代家賃",
        confidence_score: 90
      )

      service = described_class.new(pdf: pdf_file, client_code: client.code)

      messages = mock_client.messages
      expect(messages).to receive(:create).with(
        hash_including(messages: [
          hash_including(content: array_including(
            hash_including(type: "text", text: include("特定取引先"))
          ))
        ])
      ).and_return(mock_response)

      service.call
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
        service = described_class.new(pdf: pdf_file, client_code: client.code)

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

      it "エラーを返すこと" do
        service = described_class.new(pdf: pdf_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("Anthropic API エラー")
        expect(result.reason).to eq(:api_error)
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

      it "エラーを返すこと" do
        service = described_class.new(pdf: pdf_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("JSON パースエラー")
        expect(result.reason).to eq(:parse_error)
        expect(result.retryable?).to be true
      end
    end

    context "ANTHROPIC_API_KEYが未設定の場合" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)
        allow(ENV).to receive(:fetch).and_call_original
      end

      it "エラーを返すこと" do
        service = described_class.new(pdf: pdf_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("ANTHROPIC_API_KEY")
        expect(result.reason).to eq(:config_error)
        expect(result.retryable?).to be false
      end
    end

    context "INITIAL_BATCH_SIZE以下の場合" do
      let(:mock_pdf_pages) { Array.new(3) { |i| double("Page#{i + 1}") } }

      before do
        stub_const("BankStatementProcessorService::INITIAL_BATCH_SIZE", 5)
      end

      it "バッチ分割しないこと" do
        service = described_class.new(pdf: pdf_file, client_code: client.code)
        messages = mock_client.messages

        expect(messages).to receive(:create).once.and_return(mock_response)

        result = service.call
        expect(result.success?).to be true
      end
    end

    context "INITIAL_BATCH_SIZEを超える場合" do
      let(:mock_pdf_pages) { Array.new(8) { |i| double("Page#{i + 1}") } }

      let(:batch1_response_json) do
        {
          statement_period: "2026年1月",
          bank_name: "琉球銀行",
          branch_name: "名護支店",
          generated_at: Time.current.iso8601,
          transactions: [
            {
              transaction_no: 1,
              date: "2026-01-05",
              debit_account: "水道光熱費",
              debit_sub_account: "",
              debit_department: "",
              debit_partner: "ｵｷﾅﾜﾃﾞﾝﾘﾖｸ",
              debit_tax_category: "課税仕入10%（非インボイス）",
              debit_invoice: "",
              debit_amount: 45000,
              credit_account: "普通預金",
              credit_sub_account: "琉球銀行",
              credit_department: "",
              credit_partner: "",
              credit_tax_category: "",
              credit_invoice: "",
              credit_amount: 45000,
              description: "ﾃﾞﾝｷﾘﾖｳ ｵｷﾅﾜﾃﾞﾝﾘﾖｸ",
              tag: "bank",
              memo: "",
              status: "ok"
            }
          ],
          summary: {
            total_transactions: 1,
            total_withdrawals: 45000,
            total_deposits: 0,
            review_required_count: 0,
            accounts_breakdown: { "水道光熱費" => 45000 }
          }
        }.to_json
      end

      let(:batch2_response_json) do
        {
          statement_period: "2026年1月",
          bank_name: "琉球銀行",
          branch_name: "名護支店",
          generated_at: Time.current.iso8601,
          transactions: [
            {
              transaction_no: 2,
              date: "2026-01-25",
              debit_account: "普通預金",
              debit_sub_account: "琉球銀行",
              debit_department: "",
              debit_partner: "ｶ)ﾗﾝﾄﾞﾍﾞｰｽ",
              debit_tax_category: "",
              debit_invoice: "",
              debit_amount: 500000,
              credit_account: "売掛金",
              credit_sub_account: "",
              credit_department: "",
              credit_partner: "ｶ)ﾗﾝﾄﾞﾍﾞｰｽ",
              credit_tax_category: "",
              credit_invoice: "",
              credit_amount: 500000,
              description: "ﾌﾘｺﾐ ｶ)ﾗﾝﾄﾞﾍﾞｰｽ",
              tag: "bank",
              memo: "売掛金回収",
              status: "review_required"
            }
          ],
          summary: {
            total_transactions: 1,
            total_withdrawals: 0,
            total_deposits: 500000,
            review_required_count: 1,
            accounts_breakdown: { "普通預金" => 500000 }
          }
        }.to_json
      end

      let(:batch1_mock_response) do
        double("Response",
          stop_reason: "end_turn",
          content: [
            double("Content", type: "text", text: batch1_response_json)
          ]
        )
      end

      let(:batch2_mock_response) do
        double("Response",
          stop_reason: "end_turn",
          content: [
            double("Content", type: "text", text: batch2_response_json)
          ]
        )
      end

      before do
        stub_const("BankStatementProcessorService::INITIAL_BATCH_SIZE", 5)

        batch_pdf = CombinePDF.new
        allow(CombinePDF).to receive(:new).and_return(batch_pdf)
        allow(batch_pdf).to receive(:<<)
        allow(batch_pdf).to receive(:to_pdf).and_return("fake_pdf_binary")

        messages = mock_client.messages
        allow(messages).to receive(:create)
          .and_return(batch1_mock_response, batch2_mock_response)
      end

      it "バッチ分割すること" do
        service = described_class.new(pdf: pdf_file, client_code: client.code)
        messages = mock_client.messages

        # 8ページ → 2バッチ（5ページ + 3ページ）
        expect(messages).to receive(:create).twice
          .and_return(batch1_mock_response, batch2_mock_response)

        result = service.call
        expect(result.success?).to be true
      end

      it "バッチ結果のマージが正しいこと" do
        service = described_class.new(pdf: pdf_file, client_code: client.code)

        result = service.call

        expect(result.success?).to be true
        expect(result.data[:transactions].size).to eq(2)

        # transaction_no が通し連番で振り直されていること
        expect(result.data[:transactions][0][:transaction_no]).to eq(1)
        expect(result.data[:transactions][1][:transaction_no]).to eq(2)

        # summary が再計算されていること
        expect(result.data[:summary][:total_transactions]).to eq(2)
        expect(result.data[:summary][:total_withdrawals]).to eq(45000)
        expect(result.data[:summary][:total_deposits]).to eq(500000)
        expect(result.data[:summary][:review_required_count]).to eq(1)
        expect(result.data[:summary][:accounts_breakdown]).to eq(
          "水道光熱費" => 45000,
          "普通預金" => 500000
        )

        # statement_period, bank_name, branch_name は最初のバッチから取得
        expect(result.data[:statement_period]).to eq("2026年1月")
        expect(result.data[:bank_name]).to eq("琉球銀行")
        expect(result.data[:branch_name]).to eq("名護支店")

        # generated_at は現在時刻
        expect(result.data[:generated_at]).to be_present
      end
    end

    context "バッチ処理中にAPIエラーが発生した場合" do
      let(:mock_pdf_pages) { Array.new(8) { |i| double("Page#{i + 1}") } }

      before do
        stub_const("BankStatementProcessorService::INITIAL_BATCH_SIZE", 5)

        batch_pdf = CombinePDF.new
        allow(CombinePDF).to receive(:new).and_return(batch_pdf)
        allow(batch_pdf).to receive(:<<)
        allow(batch_pdf).to receive(:to_pdf).and_return("fake_pdf_binary")

        messages = mock_client.messages
        allow(messages).to receive(:create).and_raise(
          Anthropic::Errors::APIError.new(
            url: "https://api.anthropic.com/v1/messages",
            status: 500,
            headers: {},
            body: { error: { message: "Internal server error" } },
            request: double("Request"),
            response: double("Response")
          )
        )
      end

      it "エラーResultを返すこと" do
        service = described_class.new(pdf: pdf_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("Anthropic API エラー")
        expect(result.reason).to eq(:api_error)
      end
    end

    context "max_tokensで動的にバッチサイズを縮小するケース" do
      let(:mock_pdf_pages) { Array.new(12) { |i| double("Page#{i + 1}") } }

      let(:max_tokens_response) do
        double("Response",
          stop_reason: "max_tokens",
          content: [
            double("Content", type: "text", text: '{"incomplete": true}')
          ]
        )
      end

      let(:success_response) do
        double("Response",
          stop_reason: "end_turn",
          content: [
            double("Content", type: "text", text: valid_response_json)
          ]
        )
      end

      before do
        stub_const("BankStatementProcessorService::INITIAL_BATCH_SIZE", 12)
        stub_const("BankStatementProcessorService::MIN_BATCH_SIZE", 5)

        batch_pdf = CombinePDF.new
        allow(CombinePDF).to receive(:new).and_return(batch_pdf)
        allow(batch_pdf).to receive(:<<)
        allow(batch_pdf).to receive(:to_pdf).and_return("fake_pdf_binary")
      end

      it "バッチサイズを半分にしてリトライし成功すること" do
        messages = mock_client.messages
        allow(messages).to receive(:create)
          .and_return(max_tokens_response, success_response, success_response)

        service = described_class.new(pdf: pdf_file, client_code: client.code)
        result = service.call

        expect(result.success?).to be true
        expect(messages).to have_received(:create).exactly(3).times
      end
    end

    context "最小バッチサイズでもmax_tokensに達する場合" do
      let(:mock_pdf_pages) { Array.new(10) { |i| double("Page#{i + 1}") } }

      let(:max_tokens_response) do
        double("Response",
          stop_reason: "max_tokens",
          content: [
            double("Content", type: "text", text: '{"incomplete": true}')
          ]
        )
      end

      before do
        stub_const("BankStatementProcessorService::INITIAL_BATCH_SIZE", 10)
        stub_const("BankStatementProcessorService::MIN_BATCH_SIZE", 5)

        batch_pdf = CombinePDF.new
        allow(CombinePDF).to receive(:new).and_return(batch_pdf)
        allow(batch_pdf).to receive(:<<)
        allow(batch_pdf).to receive(:to_pdf).and_return("fake_pdf_binary")

        messages = mock_client.messages
        allow(messages).to receive(:create).and_return(max_tokens_response)
      end

      it "エラーを返すこと" do
        service = described_class.new(pdf: pdf_file, client_code: client.code)

        result = service.call
        expect(result.success?).to be false
        expect(result.error).to include("max_tokens")
        expect(result.reason).to eq(:api_error)
        expect(result.retryable?).to be true
      end
    end

    describe "Result#retryable?" do
      it "api_errorはretryableであること" do
        result = described_class::Result.new(success: false, data: {}, error: "error", reason: :api_error)
        expect(result.retryable?).to be true
      end

      it "config_errorはretryableでないこと" do
        result = described_class::Result.new(success: false, data: {}, error: "error", reason: :config_error)
        expect(result.retryable?).to be false
      end
    end
  end
end
