require "rails_helper"

RSpec.describe ReceiptLineProcessJob, type: :job do
  let(:client) { create(:client) }
  let(:line_user_id) { "U1234567890abcdef" }
  let(:message_id) { "msg_001" }
  let(:image_binary) { "\xFF\xD8\xFF\xE0test_image_data".b }
  let(:fingerprint) { Digest::SHA256.hexdigest(image_binary) }

  let(:line_service) { instance_double(LineMessagingService) }
  let(:success_data) do
    {
      is_receipt: true,
      receipt_date: "2026-03-13",
      transactions: [
        {
          transaction_no: 1,
          date: "2026-03-13",
          debit_account: "消耗品費",
          debit_sub_account: "",
          debit_department: "",
          debit_partner: "コンビニテスト",
          debit_tax_category: "課税仕入10%（インボイス）",
          debit_invoice: "T1234567890123",
          debit_amount: 1080,
          credit_account: "現金",
          credit_sub_account: "",
          credit_department: "",
          credit_partner: "",
          credit_tax_category: "",
          credit_invoice: "",
          credit_amount: 1080,
          description: "コンビニテスト 消耗品購入",
          tag: "receipt",
          memo: "",
          status: "ok"
        }
      ],
      summary: {
        total_transactions: 1,
        total_amount: 1080,
        review_required_count: 0
      }
    }
  end
  let(:receipt_result) do
    ReceiptProcessorService::Result.new(success: true, data: success_data, error: nil, reason: nil)
  end

  before do
    allow(LineMessagingService).to receive(:new).and_return(line_service)
    allow(line_service).to receive(:get_content).with(message_id).and_return(image_binary)
    allow(line_service).to receive(:push)
  end

  describe "#perform" do
    context "正常系" do
      let(:mock_service) { instance_double(ReceiptProcessorService, call: receipt_result) }

      before do
        allow(ReceiptProcessorService).to receive(:new).and_return(mock_service)
      end

      it "StatementBatchを作成すること" do
        expect {
          described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)
        }.to change(StatementBatch, :count).by(1)

        batch = StatementBatch.last
        expect(batch.source_type).to eq("receipt")
        expect(batch.pdf_fingerprint).to eq(fingerprint)
        expect(batch.client).to eq(client)
      end

      it "ReceiptProcessorServiceを呼び出すこと" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(ReceiptProcessorService).to have_received(:new).with(
          image: anything,
          client_code: client.code
        )
        expect(mock_service).to have_received(:call)
      end

      it "受付メッセージをLINEで送信すること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          "領収書を受け付けました。処理中です..."
        )
      end

      it "処理完了メッセージをLINEで送信すること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          a_string_including("領収書を処理しました")
        )
      end

      it "合計金額がデリミタ付きで表示されること（単一取引）" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          a_string_including("合計金額: ¥1,080")
        )
      end
    end

    context "正常系（複数取引のレシート）" do
      let(:success_data_multi) do
        {
          is_receipt: true,
          receipt_date: "2026-03-13",
          transactions: [
            {
              transaction_no: 1,
              date: "2026-03-13",
              debit_account: "仕入高",
              debit_partner: "綿半",
              debit_invoice: "T1111111111111",
              debit_amount: 4597,
              credit_account: "現金",
              credit_amount: 4597,
              description: "食品",
              status: "ok"
            },
            {
              transaction_no: 2,
              date: "2026-03-13",
              debit_account: "消耗品費",
              debit_partner: "綿半",
              debit_invoice: "T1111111111111",
              debit_amount: 1795,
              credit_account: "現金",
              credit_amount: 1795,
              description: "日用品",
              status: "ok"
            }
          ],
          summary: { total_amount: 6392 }
        }
      end
      let(:multi_result) do
        ReceiptProcessorService::Result.new(success: true, data: success_data_multi, error: nil, reason: nil)
      end
      let(:mock_service) { instance_double(ReceiptProcessorService, call: multi_result) }

      before do
        allow(ReceiptProcessorService).to receive(:new).and_return(mock_service)
      end

      it "summary.total_amountをデリミタ付きで表示すること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          a_string_including("合計金額: ¥6,392")
        )
      end

      it "件数で内訳を示すこと" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          a_string_including("内訳: 2件の仕訳")
        )
      end
    end

    context "画像取得失敗" do
      before do
        allow(line_service).to receive(:get_content).and_return(nil)
      end

      it "エラーメッセージをLINEで送信すること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          "画像の取得に失敗しました。もう一度お試しください。"
        )
      end

      it "StatementBatchを作成しないこと" do
        expect {
          described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)
        }.not_to change(StatementBatch, :count)
      end
    end

    context "重複画像" do
      before do
        create(:statement_batch, :completed, client: client, source_type: "receipt", pdf_fingerprint: fingerprint)
      end

      it "重複メッセージをLINEで送信すること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          "この画像は既に処理済みです。"
        )
      end
    end

    context "過去にfailedになった同一画像" do
      let(:mock_service) { instance_double(ReceiptProcessorService, call: receipt_result) }

      before do
        create(:statement_batch, :failed, client: client, source_type: "receipt", pdf_fingerprint: fingerprint)
        allow(ReceiptProcessorService).to receive(:new).and_return(mock_service)
      end

      it "重複扱いせず新規バッチを作成して処理すること" do
        expect {
          described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)
        }.to change(StatementBatch, :count).by(1)
      end

      it "重複メッセージを送信しないこと" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).not_to have_received(:push).with(
          line_user_id,
          "この画像は既に処理済みです。"
        )
      end
    end

    context "file_not_found エラー" do
      let(:file_not_found_result) do
        ReceiptProcessorService::Result.new(
          success: false, data: {}, error: "画像ファイルが見つかりません: ActiveStorage::FileNotFoundError", reason: :file_not_found
        )
      end

      before do
        allow(ReceiptProcessorService).to receive(:new).and_return(
          instance_double(ReceiptProcessorService, call: file_not_found_result)
        )
      end

      it "専用エラーメッセージをLINEで送信すること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          "画像ファイルの読み込みに失敗しました。もう一度送信してください。"
        )
      end

      it "リトライせずStatementBatchをfailedにすること" do
        expect {
          described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)
        }.not_to raise_error

        batch = StatementBatch.last
        expect(batch.status).to eq("failed")
      end
    end

    context "非領収書画像" do
      let(:non_receipt_result) do
        ReceiptProcessorService::Result.new(
          success: false, data: {}, error: "領収書として認識できません", reason: :non_receipt
        )
      end

      before do
        allow(ReceiptProcessorService).to receive(:new).and_return(
          instance_double(ReceiptProcessorService, call: non_receipt_result)
        )
      end

      it "非領収書メッセージをLINEで送信すること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          "領収書またはレシートの画像を送信してください。"
        )
      end

      it "StatementBatchをfailedにすること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        batch = StatementBatch.last
        expect(batch.status).to eq("failed")
      end
    end

    context "重複レシート（インボイス一致）" do
      let(:mock_service) { instance_double(ReceiptProcessorService, call: receipt_result) }

      before do
        allow(ReceiptProcessorService).to receive(:new).and_return(mock_service)
        create(:journal_entry, :receipt,
          client: client,
          source_period: "2026年3月",
          transaction_no: 1,
          date: "2026-03-13",
          debit_invoice: "T1234567890123",
          debit_partner: "別店舗",
          debit_amount: 1080
        )
      end

      it "新規JournalEntryを作成しないこと" do
        expect {
          described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)
        }.not_to change(JournalEntry, :count)
      end

      it "StatementBatchをduplicateにすること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        batch = StatementBatch.last
        expect(batch.status).to eq("duplicate")
      end

      it "重複通知をLINEで送信すること" do
        described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)

        expect(line_service).to have_received(:push).with(
          line_user_id,
          a_string_including("このレシートは処理済みです")
        )
      end
    end

    context "リトライ可能なAPIエラー" do
      let(:error_result) do
        ReceiptProcessorService::Result.new(
          success: false, data: {}, error: "Anthropic API エラー", reason: :api_error
        )
      end

      before do
        allow(ReceiptProcessorService).to receive(:new).and_return(
          instance_double(ReceiptProcessorService, call: error_result)
        )
      end

      it "RetryableErrorをraiseすること" do
        expect {
          described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)
        }.to raise_error(ReceiptLineProcessJob::RetryableError)
      end

      it "StatementBatchをprocessingのまま残すこと" do
        expect {
          described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)
        }.to raise_error(ReceiptLineProcessJob::RetryableError)

        batch = StatementBatch.last
        expect(batch.status).to eq("processing")
      end

      it "LINEエラー通知を送信しないこと" do
        expect {
          described_class.new.perform(client_id: client.id, message_id: message_id, line_user_id: line_user_id)
        }.to raise_error(ReceiptLineProcessJob::RetryableError)

        expect(line_service).not_to have_received(:push).with(
          line_user_id,
          "処理中にエラーが発生しました。もう一度お試しください。"
        )
      end
    end
  end
end
