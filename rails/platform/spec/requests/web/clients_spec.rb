require 'rails_helper'

RSpec.describe "Web::Clients", type: :request do
  let(:user) { create(:user) }

  describe "GET /clients (index)" do
    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get clients_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "200を返すこと" do
        get clients_path
        expect(response).to have_http_status(:ok)
      end

      it "activeとtrialのクライアントが表示されること" do
        active = create(:client, status: "active", name: "アクティブ社")
        trial = create(:client, status: "trial", name: "トライアル社")
        create(:client, status: "inactive", name: "非アクティブ社")

        get clients_path
        expect(response.body).to include("アクティブ社")
        expect(response.body).to include("トライアル社")
        expect(response.body).not_to include("非アクティブ社")
      end

      it "検索でフィルタできること" do
        create(:client, code: "ikigai_stay", name: "イキガイステイ")
        create(:client, code: "oku_resort", name: "奥リゾート")

        get clients_path(query: "ikigai")
        expect(response.body).to include("イキガイステイ")
        expect(response.body).not_to include("奥リゾート")
      end

      it "結果が空の場合メッセージが表示されること" do
        get clients_path(query: "存在しない")
        expect(response.body).to include("クライアントが見つかりません")
      end
    end
  end

  describe "GET /clients/:code (show)" do
    let!(:client) { create(:client, code: "test_client", name: "テスト社") }

    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get client_path(client)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "200を返すこと" do
        get client_path(client)
        expect(response).to have_http_status(:ok)
      end

      it "クライアント情報が表示されること" do
        get client_path(client)
        expect(response.body).to include("テスト社")
        expect(response.body).to include("test_client")
      end

      it "機能カードのリンクが表示されること" do
        get client_path(client)
        expect(response.body).to include("仕訳台帳")
        expect(response.body).to include("Amex明細処理")
        expect(response.body).to include("銀行明細処理")
        expect(response.body).to include("請求書処理")
      end

      it "hotelクライアントは清掃マニュアルカードが表示されること" do
        hotel_client = create(:client, :hotel, code: "hotel_test", name: "ホテルテスト")
        get client_path(hotel_client)
        expect(response.body).to include("清掃マニュアル")
      end

      it "非hotelクライアントは清掃マニュアルカードが表示されないこと" do
        get client_path(client)
        expect(response.body).not_to include("清掃マニュアル")
      end

      it "存在しないコードの場合リダイレクトすること" do
        get client_path(id: "nonexistent")
        expect(response).to redirect_to(clients_path)
        expect(flash[:alert]).to eq("クライアントが見つかりません")
      end
    end
  end

  describe "GET /clients/new (new)" do
    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get new_client_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "200を返すこと" do
        get new_client_path
        expect(response).to have_http_status(:ok)
      end

      it "フォームが表示されること" do
        get new_client_path
        expect(response.body).to include("新規クライアント作成")
      end
    end
  end

  describe "POST /clients (create)" do
    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        post clients_path, params: { client: { code: "new_client", name: "新規社" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "正常なパラメータで作成できること" do
        expect {
          post clients_path, params: { client: { code: "new_client", name: "新規社", industry: "accommodation", status: "active" } }
        }.to change(Client, :count).by(1)

        client = Client.find_by(code: "new_client")
        expect(response).to redirect_to(client_path(client))
        expect(client.name).to eq("新規社")
        expect(client.industry).to eq("accommodation")
        expect(client.status).to eq("active")
      end

      it "バリデーションエラー時にフォームが再表示されること" do
        post clients_path, params: { client: { code: "", name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("新規クライアント作成")
      end

      it "code重複時にエラーが表示されること" do
        create(:client, code: "existing")
        post clients_path, params: { client: { code: "existing", name: "重複社", status: "active" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /clients/:code/edit (edit)" do
    let!(:client) { create(:client, code: "edit_target", name: "編集対象社") }

    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get edit_client_path(client)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "200を返すこと" do
        get edit_client_path(client)
        expect(response).to have_http_status(:ok)
      end

      it "編集フォームが表示されること" do
        get edit_client_path(client)
        expect(response.body).to include("編集対象社")
        expect(response.body).to include("を編集")
      end

      it "存在しないコードの場合リダイレクトすること" do
        get edit_client_path(id: "nonexistent")
        expect(response).to redirect_to(clients_path)
      end
    end
  end

  describe "PATCH /clients/:code (update)" do
    let!(:client) { create(:client, code: "update_target", name: "更新前社") }

    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        patch client_path(client), params: { client: { name: "更新後社" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "正常に更新できること" do
        patch client_path(client), params: { client: { name: "更新後社", industry: "activity" } }
        expect(response).to redirect_to(client_path(client))
        client.reload
        expect(client.name).to eq("更新後社")
        expect(client.industry).to eq("activity")
      end

      it "codeが変更されないこと" do
        patch client_path(client), params: { client: { code: "hacked_code", name: "更新後社" } }
        client.reload
        expect(client.code).to eq("update_target")
      end

      it "バリデーションエラー時にフォームが再表示されること" do
        patch client_path(client), params: { client: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("を編集")
      end
    end
  end

  describe "DELETE /clients/:code (destroy)" do
    let!(:client) { create(:client, code: "delete_target", name: "削除対象社", status: "active") }

    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        delete client_path(client)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "論理削除されること（statusがinactiveに変更）" do
        delete client_path(client)
        expect(response).to redirect_to(clients_path)
        client.reload
        expect(client.status).to eq("inactive")
      end

      it "物理削除されないこと" do
        expect {
          delete client_path(client)
        }.not_to change(Client, :count)
      end

      it "フラッシュメッセージが表示されること" do
        delete client_path(client)
        expect(flash[:notice]).to eq("クライアントを無効化しました")
      end
    end
  end

  describe "GET / (root)" do
    context "認証済みの場合" do
      before { sign_in user }

      it "クライアント一覧が表示されること" do
        get root_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("クライアント一覧")
      end
    end
  end
end
