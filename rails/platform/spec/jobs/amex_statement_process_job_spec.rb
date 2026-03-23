require "rails_helper"

RSpec.describe AmexStatementProcessJob, type: :job do
  let(:client) { create(:client) }
  let(:batch) { create(:statement_batch, :processing, client: client) }

  let(:mock_result_data) do
    {
      statement_period: "2026年1月",
      card_type: "アメリカン・エキスプレス",
      generated_at: Time.current.iso8601,
      transactions: [
        {
          transaction_no: 1,
          date: "2026-01-05",
          debit_account: "消耗品費",
          debit_sub_account: "",
          debit_department: "",
          debit_partner: "Amazon.co.jp",
          debit_tax_category: "課税仕入10%（非インボイス）",
          debit_invoice: "",
          debit_amount: 3280,
          credit_account: "未払金",
          credit_sub_account: "アメックス",
          credit_department: "",
          credit_partner: "",
          credit_tax_category: "",
          credit_invoice: "",
          credit_amount: 3280,
          description: "Amazon.co.jp 事務用品購入",
          tag: "amex",
          memo: "",
          cardholder: "山田太郎",
          status: "ok"
        }
      ],
      summary: {
        total_transactions: 1,
        total_amount: 3280,
        review_required_count: 0,
        accounts_breakdown: { "消耗品費" => 3280 }
      }
    }
  end

  let(:mock_result) do
    AmexStatementProcessorService::Result.new(
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
    allow(AmexStatementProcessorService).to receive(:new).and_return(
      instance_double(AmexStatementProcessorService, call: mock_result)
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
    expect(entry.cardholder).to eq("山田太郎")
    expect(entry.source_type).to eq("amex")

    debit = entry.debit_lines.first
    expect(debit.account).to eq("消耗品費")
    expect(debit.amount).to eq(3280)

    credit = entry.credit_lines.first
    expect(credit.account).to eq("未払金")
    expect(credit.amount).to eq(3280)
  end

  context "retryableなエラーの場合" do
    let(:mock_result) do
      AmexStatementProcessorService::Result.new(
        success: false, data: {}, error: "Anthropic API エラー: timeout", reason: :api_error
      )
    end

    it "RetryableErrorをraiseすること" do
      job = described_class.new(batch.id)

      expect { job.perform(batch.id) }.to raise_error(AmexStatementProcessJob::RetryableError, "Anthropic API エラー: timeout")
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
      AmexStatementProcessorService::Result.new(
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

    expect(AmexStatementProcessorService).not_to have_received(:new)
  end
end
