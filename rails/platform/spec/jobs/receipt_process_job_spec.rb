require "rails_helper"

RSpec.describe ReceiptProcessJob, type: :job do
  let(:client) { create(:client) }
  let(:batch) { create(:statement_batch, :processing, client: client, source_type: "receipt") }

  let(:mock_result_data) do
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
    }
  end

  let(:mock_result) do
    ReceiptProcessorService::Result.new(
      success: true,
      data: mock_result_data,
      error: nil,
      reason: nil
    )
  end

  before do
    batch.pdf.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/test_receipt.jpg")),
      filename: "test_receipt.jpg",
      content_type: "image/jpeg"
    )
    allow(ReceiptProcessorService).to receive(:new).and_return(
      instance_double(ReceiptProcessorService, call: mock_result)
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
    expect(entry.cardholder).to eq("")
    expect(entry.source_type).to eq("receipt")
    expect(entry.tag).to eq("receipt")

    debit = entry.debit_lines.first
    expect(debit.account).to eq("仕入高")
    expect(debit.amount).to eq(2160)

    credit = entry.credit_lines.first
    expect(credit.account).to eq("現金")
    expect(credit.amount).to eq(2160)
  end

  it "source_periodにreceipt_dateの年月を使用すること" do
    described_class.perform_now(batch.id)

    entry = JournalEntry.last
    expect(entry.source_period).to eq("2026年3月")
  end

  context "非領収書画像の場合（リトライ不要）" do
    let(:mock_result) do
      ReceiptProcessorService::Result.new(
        success: false, data: {}, error: "領収書として認識できません", reason: :non_receipt
      )
    end

    it "リトライせずにステータスをfailedに更新すること" do
      described_class.perform_now(batch.id)

      batch.reload
      expect(batch.status).to eq("failed")
      expect(batch.error_message).to eq("領収書として認識できません")
    end

    it "JournalEntryを作成しないこと" do
      expect {
        described_class.perform_now(batch.id)
      }.not_to change(JournalEntry, :count)
    end
  end

  context "非対応フォーマットの場合（リトライ不要）" do
    let(:mock_result) do
      ReceiptProcessorService::Result.new(
        success: false, data: {}, error: "対応していない画像フォーマットです", reason: :unsupported_format
      )
    end

    it "リトライせずにステータスをfailedに更新すること" do
      described_class.perform_now(batch.id)

      batch.reload
      expect(batch.status).to eq("failed")
      expect(batch.error_message).to eq("対応していない画像フォーマットです")
    end
  end

  context "APIエラーの場合（リトライ対象）" do
    let(:mock_result) do
      ReceiptProcessorService::Result.new(
        success: false, data: {}, error: "Anthropic API エラー: timeout", reason: :api_error
      )
    end

    it "リトライ用にRetryableErrorをraiseすること" do
      job = described_class.new(batch.id)

      expect { job.perform(batch.id) }.to raise_error(ReceiptProcessJob::RetryableError, "Anthropic API エラー: timeout")
    end
  end

  context "リトライ上限到達の場合" do
    let(:mock_result) do
      ReceiptProcessorService::Result.new(
        success: false, data: {}, error: "Anthropic API エラー: timeout", reason: :api_error
      )
    end

    it "ステータスをfailedに更新すること" do
      job = described_class.new(batch.id)
      job.exception_executions = { "[ReceiptProcessJob::RetryableError]" => 1 }

      job.perform_now

      batch.reload
      expect(batch.status).to eq("failed")
      expect(batch.error_message).to include("リトライ上限到達")
    end
  end

  context "receipt_dateが不正な場合" do
    let(:mock_result_data) do
      super().merge(receipt_date: "invalid-date")
    end

    it "source_periodをnilにして処理を完了すること" do
      described_class.perform_now(batch.id)

      batch.reload
      expect(batch.status).to eq("completed")

      entry = JournalEntry.last
      expect(entry.source_period).to be_nil
    end
  end

  context "仕訳データのバリデーションエラーの場合" do
    let(:mock_result_data) do
      {
        is_receipt: true,
        receipt_date: "2026-03-01",
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

    expect(ReceiptProcessorService).not_to have_received(:new)
  end
end
