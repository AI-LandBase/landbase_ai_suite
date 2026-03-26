require "rails_helper"

RSpec.describe "Api::V1::CleaningSessions", type: :request do
  let(:client) { create(:client, :hotel, code: "test_hotel") }
  let(:client_code) { client.code }
  let(:api_token_record) { create(:api_token) }
  let(:authorization_header) { { "Authorization" => "Bearer #{api_token_record.raw_token}" } }
  let(:manual) { create(:cleaning_manual, :published, client: client) }

  describe "POST /api/v1/cleaning_manuals/:id/cleaning_sessions" do
    it "セッションを作成すること" do
      post "/api/v1/cleaning_manuals/#{manual.id}/cleaning_sessions",
           params: { client_code: client_code, staff_name: "田中" },
           headers: authorization_header

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)
      expect(data["staff_name"]).to eq("田中")
      expect(data["status"]).to eq("in_progress")
      expect(data["total_steps"]).to eq(1)
    end

    it "staff_name がない場合エラーを返すこと" do
      post "/api/v1/cleaning_manuals/#{manual.id}/cleaning_sessions",
           params: { client_code: client_code },
           headers: authorization_header

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "未公開マニュアルの場合404を返すこと" do
      draft_manual = create(:cleaning_manual, client: client, status: "draft")

      post "/api/v1/cleaning_manuals/#{draft_manual.id}/cleaning_sessions",
           params: { client_code: client_code, staff_name: "田中" },
           headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end

    it "他テナントのマニュアルでセッション作成できないこと" do
      other_client = create(:client, :hotel, code: "other_hotel")
      other_manual = create(:cleaning_manual, :published, client: other_client)

      post "/api/v1/cleaning_manuals/#{other_manual.id}/cleaning_sessions",
           params: { client_code: client_code, staff_name: "田中" },
           headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end

    it "非ホテルクライアントの場合403を返すこと" do
      restaurant = create(:client, code: "restaurant_client", industry: "restaurant")

      post "/api/v1/cleaning_manuals/#{manual.id}/cleaning_sessions",
           params: { client_code: restaurant.code, staff_name: "田中" },
           headers: authorization_header

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/cleaning_sessions/:id" do
    it "セッション詳細を返すこと" do
      session = create(:cleaning_session, cleaning_manual: manual, client: client)

      get "/api/v1/cleaning_sessions/#{session.id}",
          params: { client_code: client_code },
          headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["id"]).to eq(session.id)
      expect(data["staff_name"]).to eq(session.staff_name)
    end

    it "他テナントのセッションにアクセスできないこと" do
      other_client = create(:client, :hotel, code: "other_hotel")
      other_manual = create(:cleaning_manual, :published, client: other_client)
      other_session = create(:cleaning_session, cleaning_manual: other_manual, client: other_client)

      get "/api/v1/cleaning_sessions/#{other_session.id}",
          params: { client_code: client_code },
          headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/cleaning_sessions/:id/current_step" do
    it "現在のステップ情報を返すこと" do
      session = CleaningSessionService.start(cleaning_manual: manual, staff_name: "田中", client: client)

      get "/api/v1/cleaning_sessions/#{session.id}/current_step",
          params: { client_code: client_code },
          headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["task"]).to eq("ベッドメイキング")
      expect(data["area_name"]).to eq("寝室")
    end

    it "全ステップ完了時はメッセージを返すこと" do
      session = CleaningSessionService.start(cleaning_manual: manual, staff_name: "田中", client: client)
      session.cleaning_session_steps.update_all(status: "passed")

      get "/api/v1/cleaning_sessions/#{session.id}/current_step",
          params: { client_code: client_code },
          headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["message"]).to be_present
    end
  end

  describe "PATCH /api/v1/cleaning_sessions/:id/skip" do
    it "ステップをスキップすること" do
      session = CleaningSessionService.start(cleaning_manual: manual, staff_name: "田中", client: client)

      patch "/api/v1/cleaning_sessions/#{session.id}/skip",
            params: { client_code: client_code },
            headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["skipped_step"]["task"]).to eq("ベッドメイキング")
    end

    it "中断中のセッションではスキップできないこと" do
      session = CleaningSessionService.start(cleaning_manual: manual, staff_name: "田中", client: client)
      session.update!(status: "suspended")

      patch "/api/v1/cleaning_sessions/#{session.id}/skip",
            params: { client_code: client_code },
            headers: authorization_header

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/cleaning_sessions/:id/suspend" do
    it "セッションを中断すること" do
      session = CleaningSessionService.start(cleaning_manual: manual, staff_name: "田中", client: client)

      patch "/api/v1/cleaning_sessions/#{session.id}/suspend",
            params: { client_code: client_code },
            headers: authorization_header

      expect(response).to have_http_status(:ok)
      expect(session.reload.status).to eq("suspended")
    end
  end

  describe "PATCH /api/v1/cleaning_sessions/:id/resume" do
    it "セッションを再開すること" do
      session = CleaningSessionService.start(cleaning_manual: manual, staff_name: "田中", client: client)
      session.update!(status: "suspended")

      patch "/api/v1/cleaning_sessions/#{session.id}/resume",
            params: { client_code: client_code },
            headers: authorization_header

      expect(response).to have_http_status(:ok)
      expect(session.reload.status).to eq("in_progress")
    end

    it "進行中のセッションでは再開できないこと" do
      session = CleaningSessionService.start(cleaning_manual: manual, staff_name: "田中", client: client)

      patch "/api/v1/cleaning_sessions/#{session.id}/resume",
            params: { client_code: client_code },
            headers: authorization_header

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/cleaning_sessions/:id/report" do
    it "レポートを返すこと" do
      session = CleaningSessionService.start(cleaning_manual: manual, staff_name: "田中", client: client)
      CleaningSessionService.complete(session)

      get "/api/v1/cleaning_sessions/#{session.id}/report",
          params: { client_code: client_code },
          headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["staff_name"]).to eq("田中")
      expect(data["status"]).to eq("completed")
    end
  end
end
