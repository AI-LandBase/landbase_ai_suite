require "rails_helper"

RSpec.describe BankStatementProcessJob, type: :job do
  let(:client) { create(:client) }
  let(:batch) { create(:statement_batch, :processing, client: client, source_type: "bank") }

  let(:mock_result_data) do
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
    }
  end

  let(:mock_result) do
    BankStatementProcessorService::Result.new(
      success: true,
      data: mock_result_data,
      error: nil,
      reason: nil
    )
  end

  before do
    batch.pdf.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/test_statement.pdf")),
      filename: "test_statement.pdf",
      content_type: "application/pdf"
    )
    allow(BankStatementProcessorService).to receive(:new).and_return(
      instance_double(BankStatementProcessorService, call: mock_result)
    )
  end

  it "成功時にステータスをcompletedに更新すること" do
    described_class.perform_now(batch.id)

    batch.reload
    expect(batch.status).to eq("completed")
    expect(batch.summary).to be_present
    expect(batch.error_message).to be_nil
  end

  it "成功時にJournalEntryとJournalEntryLineを作成すること" do
    expect {
      described_class.perform_now(batch.id)
    }.to change(JournalEntry, :count).by(1)
      .and change(JournalEntryLine, :count).by(2)

    entry = JournalEntry.last
    expect(entry.client).to eq(client)
    expect(entry.statement_batch).to eq(batch)
    expect(entry.source_type).to eq("bank")
    expect(entry.tag).to eq("bank")

    debit = entry.debit_lines.first
    expect(debit.account).to eq("水道光熱費")
    expect(debit.amount).to eq(45000)

    credit = entry.credit_lines.first
    expect(credit.account).to eq("普通預金")
    expect(credit.amount).to eq(45000)
  end

  context "retryableなエラーの場合" do
    let(:mock_result) do
      BankStatementProcessorService::Result.new(
        success: false, data: {}, error: "Anthropic API エラー: timeout", reason: :api_error
      )
    end

    it "RetryableErrorをraiseすること" do
      job = described_class.new(batch.id)

      expect { job.perform(batch.id) }.to raise_error(BankStatementProcessJob::RetryableError, "Anthropic API エラー: timeout")
    end

    it "JournalEntryを作成しないこと" do
      job = described_class.new(batch.id)

      expect {
        job.perform(batch.id) rescue nil
      }.not_to change(JournalEntry, :count)
    end
  end

  context "non-retryableなエラーの場合" do
    let(:mock_result) do
      BankStatementProcessorService::Result.new(
        success: false, data: {}, error: "ANTHROPIC_API_KEY が設定されていません", reason: :config_error
      )
    end

    it "ステータスをfailedに更新すること" do
      described_class.perform_now(batch.id)

      batch.reload
      expect(batch.status).to eq("failed")
      expect(batch.error_message).to eq("ANTHROPIC_API_KEY が設定されていません")
    end

    it "JournalEntryを作成しないこと" do
      expect {
        described_class.perform_now(batch.id)
      }.not_to change(JournalEntry, :count)
    end
  end

  context "仕訳データのバリデーションエラーの場合" do
    let(:mock_result_data) do
      {
        statement_period: "2026年1月",
        transactions: [
          {
            transaction_no: 1,
            date: nil,
            debit_account: nil,
            debit_amount: 100,
            credit_account: nil,
            credit_amount: 100,
            description: "テスト"
          }
        ],
        summary: {}
      }
    end

    it "ステータスをfailedに更新すること" do
      described_class.perform_now(batch.id)

      batch.reload
      expect(batch.status).to eq("failed")
      expect(batch.error_message).to include("仕訳データの保存に失敗")
    end

    it "JournalEntryを作成しないこと" do
      expect {
        described_class.perform_now(batch.id)
      }.not_to change(JournalEntry, :count)
    end
  end

  it "レコードが存在しない場合は静かに終了すること" do
    expect {
      described_class.perform_now(-1)
    }.not_to raise_error
  end

  it "既にprocessingでないレコードはスキップすること" do
    batch.update!(status: "completed")

    described_class.perform_now(batch.id)

    expect(BankStatementProcessorService).not_to have_received(:new)
  end
end
