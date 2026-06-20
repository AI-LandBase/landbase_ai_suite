require "rails_helper"

RSpec.describe "Web::Receipts", type: :request do
  let(:user) { create(:user) }

  describe "GET /receipts/new" do
    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get new_receipt_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "200を返すこと" do
        get new_receipt_path
        expect(response).to have_http_status(:ok)
      end

      it "アップロードUIが表示されること" do
        get new_receipt_path(client_code: "test_client")
        expect(response.body).to include("領収書")
        expect(response.body).to include("receipt-upload")
      end
    end
  end
end
