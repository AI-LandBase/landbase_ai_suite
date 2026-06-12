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
        delete statement_batch_path(batch)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "バッチ・紐づく仕訳・仕訳行をまとめて削除すること (dependent: :destroy)" do
        expect {
          delete statement_batch_path(batch)
        }.to change(StatementBatch, :count).by(-1)
         .and change(JournalEntry, :count).by(-1)
         .and change(JournalEntryLine, :count).by(-2)
      end

      it "削除後は仕訳一覧にリダイレクトすること" do
        delete statement_batch_path(batch)
        expect(response).to redirect_to(journal_entries_path(client_code: client.code))
        expect(flash[:notice]).to include("削除")
      end

      it "紐づく仕訳が複数あっても全部削除すること" do
        create(:journal_entry, client: client, statement_batch: batch,
               debit_amount: 2000, credit_amount: 2000)
        create(:journal_entry, client: client, statement_batch: batch,
               debit_amount: 3000, credit_amount: 3000)

        expect {
          delete statement_batch_path(batch)
        }.to change(JournalEntry, :count).by(-3)
         .and change(JournalEntryLine, :count).by(-6)
      end
    end
  end
end
