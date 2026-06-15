require "rails_helper"

RSpec.describe "Web::StatementBatches", type: :request do
  let(:user) { create(:user) }
  let(:client) { create(:client, code: "test_client", name: "テスト社") }

  describe "DELETE /statement_batches/:id" do
    let(:batch) { create(:statement_batch, client: client) }
    let!(:entry) do
      create(:journal_entry, client: client, statement_batch: batch,
             debit_amount: 1000, credit_amount: 1000)
    end

    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        delete statement_batch_path(batch, client_code: client.code)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "バッチ・紐づく仕訳・仕訳行をまとめて削除すること (dependent: :destroy)" do
        expect {
          delete statement_batch_path(batch, client_code: client.code)
        }.to change(StatementBatch, :count).by(-1)
         .and change(JournalEntry, :count).by(-1)
         .and change(JournalEntryLine, :count).by(-2)
      end

      it "削除後は仕訳一覧にリダイレクトすること" do
        delete statement_batch_path(batch, client_code: client.code)
        expect(response).to redirect_to(journal_entries_path(client_code: client.code))
        expect(flash[:notice]).to include("削除")
      end

      it "紐づく仕訳が複数あっても全部削除すること" do
        create(:journal_entry, client: client, statement_batch: batch,
               debit_amount: 2000, credit_amount: 2000)
        create(:journal_entry, client: client, statement_batch: batch,
               debit_amount: 3000, credit_amount: 3000)

        expect {
          delete statement_batch_path(batch, client_code: client.code)
        }.to change(JournalEntry, :count).by(-3)
         .and change(JournalEntryLine, :count).by(-6)
      end

      it "別テナントの client_code では削除できないこと" do
        other_client = create(:client, code: "other_client")

        expect {
          delete statement_batch_path(batch, client_code: other_client.code)
        }.not_to change(StatementBatch, :count)
        expect(response).to redirect_to(clients_path)
      end
    end
  end

  describe "GET /statement_batches/:id" do
    context "認証済みの場合" do
      before { sign_in user }

      it "処理中(processing)は削除ボタンを表示しないこと（非同期ジョブとの削除レース防止）" do
        batch = create(:statement_batch, :processing, client: client)
        get statement_batch_path(batch)
        expect(response.body).not_to include("バッチごと削除")
      end

      it "処理完了(completed)は削除ボタンを表示すること" do
        batch = create(:statement_batch, :completed, client: client)
        get statement_batch_path(batch)
        expect(response.body).to include("バッチごと削除")
      end
    end
  end
end
