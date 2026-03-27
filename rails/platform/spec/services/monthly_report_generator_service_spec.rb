require "rails_helper"

RSpec.describe MonthlyReportGeneratorService do
  let(:client) { create(:client, code: "report_test", industry: "hotel") }
  let(:year_month) { "2026-02" }
  let(:service) { described_class.new(client: client, year_month: year_month) }

  let(:report_markdown) do
    <<~MD
      ## エグゼクティブサマリー

      2月は前月比で売上が10%増加しました。

      ## 収支概要

      | 項目 | 金額 |
      |------|------|
      | 売上 | 1,000,000円 |
      | 費用 | 800,000円 |
      | 利益 | 200,000円 |
    MD
  end

  let(:mock_response) do
    double("Response",
      content: [
        double("Content", type: "text", text: report_markdown)
      ]
    )
  end

  describe "#call" do
    context "ANTHROPIC_API_KEYが未設定の場合" do
      before { allow(ENV).to receive(:[]).and_call_original; allow(ENV).to receive(:fetch).and_call_original; allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil) }

      it "config_errorを返すこと" do
        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:config_error)
        expect(result.error).to include("ANTHROPIC_API_KEY")
      end

      it "リトライ不可であること" do
        result = service.call
        expect(result.retryable?).to be false
      end
    end

    context "仕訳データがない場合" do
      before { allow(ENV).to receive(:[]).and_call_original; allow(ENV).to receive(:fetch).and_call_original; allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-key") }

      it "no_dataエラーを返すこと" do
        result = service.call
        expect(result.success?).to be false
        expect(result.reason).to eq(:no_data)
        expect(result.error).to include("仕訳データがありません")
      end
    end

    context "仕訳データがある場合" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-key")

        create(:journal_entry, client: client, date: Date.new(2026, 2, 15),
               source_type: "bank", debit_account: "水道光熱費", credit_account: "普通預金",
               debit_amount: 50_000, credit_amount: 50_000)
        create(:journal_entry, client: client, date: Date.new(2026, 2, 20),
               source_type: "bank", debit_account: "通信費", credit_account: "普通預金",
               debit_amount: 10_000, credit_amount: 10_000)

        mock_client = double("Anthropic::Client")
        allow(mock_client).to receive_message_chain(:messages, :create).and_return(mock_response)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client)
      end

      it "レポートを正常に生成すること" do
        result = service.call
        expect(result.success?).to be true
        expect(result.data).to be_a(MonthlyReport)
        expect(result.data.persisted?).to be true
      end

      it "レポートの内容が正しいこと" do
        result = service.call
        report = result.data
        expect(report.client).to eq(client)
        expect(report.year_month).to eq("2026-02")
        expect(report.content).to include("エグゼクティブサマリー")
        expect(report.status).to eq("draft")
        expect(report.generated_at).to be_present
      end

      it "同一年月のレポートが存在する場合は上書きすること" do
        create(:monthly_report, client: client, year_month: "2026-02", content: "古いレポート")
        result = service.call
        expect(result.success?).to be true
        expect(MonthlyReport.where(client: client, year_month: "2026-02").count).to eq(1)
        expect(result.data.content).to include("エグゼクティブサマリー")
      end
    end

    context "業種別プロンプトの切り替え" do
      let(:mock_client_obj) { double("Anthropic::Client") }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-key")

        create(:journal_entry, client: client, date: Date.new(2026, 2, 15),
               source_type: "bank", debit_account: "仕入高", credit_account: "普通預金",
               debit_amount: 100_000, credit_amount: 100_000)

        allow(mock_client_obj).to receive_message_chain(:messages, :create).and_return(mock_response)
        allow(Anthropic::Client).to receive(:new).and_return(mock_client_obj)
      end

      it "hotel業種の場合、宿泊業プロンプトが使用されること" do
        client.update!(industry: "hotel")
        expect(mock_client_obj).to receive_message_chain(:messages, :create) do |**args|
          expect(args[:messages].first[:content]).to include("稼働率")
          mock_response
        end
        service.call
      end

      it "restaurant業種の場合、飲食業プロンプトが使用されること" do
        client.update!(industry: "restaurant")
        restaurant_service = described_class.new(client: client, year_month: year_month)
        expect(mock_client_obj).to receive_message_chain(:messages, :create) do |**args|
          expect(args[:messages].first[:content]).to include("原価率")
          mock_response
        end
        restaurant_service.call
      end
    end
  end
end
