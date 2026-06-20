require "rails_helper"

RSpec.describe "Api::V1::Receipts", type: :request do
  let(:client) { create(:client, code: "test_client") }
  let(:client_code) { client.code }
  let(:api_token_record) { create(:api_token) }
  let(:authorization_header) { { "Authorization" => "Bearer #{api_token_record.raw_token}" } }

  describe "POST /api/v1/receipts/process_receipt" do
    let(:test_image) { fixture_file_upload("test_receipt.jpg", "image/jpeg") }
    let(:valid_params) { { client_code: client_code, image: test_image } }

    before do
      allow(ReceiptProcessJob).to receive(:perform_later)
    end

    it "202を返しジョブをエンキューすること" do
      post "/api/v1/receipts/process_receipt", params: valid_params, headers: authorization_header

      expect(response).to have_http_status(:accepted)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("processing")
      expect(data["id"]).to be_present
      expect(ReceiptProcessJob).to have_received(:perform_later).with(anything)
      expect(StatementBatch.count).to eq(1)
      expect(StatementBatch.last.source_type).to eq("receipt")
    end

    it "画像がない場合エラーを返すこと" do
      post "/api/v1/receipts/process_receipt", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("画像")
    end

    it "画像以外（PDF）の場合エラーを返すこと" do
      non_image = fixture_file_upload("test_statement.pdf", "application/pdf")

      post "/api/v1/receipts/process_receipt", params: {
        client_code: client_code, image: non_image
      }, headers: authorization_header

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("画像")
    end

    it "client_codeがない場合400を返すこと" do
      post "/api/v1/receipts/process_receipt", params: { image: test_image }, headers: authorization_header
      expect(response).to have_http_status(:bad_request)
    end

    it "存在しないクライアントの場合404を返すこと" do
      post "/api/v1/receipts/process_receipt", params: {
        client_code: "nonexistent", image: test_image
      }, headers: authorization_header
      expect(response).to have_http_status(:not_found)
    end

    context "重複画像検知" do
      let(:fingerprint) do
        Digest::SHA256.hexdigest(File.read(Rails.root.join("spec/fixtures/files/test_receipt.jpg")))
      end

      it "同一画像が処理済みの場合409を返すこと" do
        create(:statement_batch, :completed, client: client, source_type: "receipt", pdf_fingerprint: fingerprint)

        post "/api/v1/receipts/process_receipt", params: valid_params, headers: authorization_header

        expect(response).to have_http_status(:conflict)
        data = JSON.parse(response.body)
        expect(data["duplicate"]).to be true
        expect(data["existing_batch_id"]).to be_present
        expect(data["error"]).to include("処理済み")
      end

      it "同一画像が重複(duplicate)状態の場合も409を返すこと" do
        create(:statement_batch, client: client, source_type: "receipt", status: "duplicate", pdf_fingerprint: fingerprint)

        post "/api/v1/receipts/process_receipt", params: valid_params, headers: authorization_header
        expect(response).to have_http_status(:conflict)
      end

      it "force: trueで重複チェックをスキップできること" do
        create(:statement_batch, :completed, client: client, source_type: "receipt", pdf_fingerprint: fingerprint)

        post "/api/v1/receipts/process_receipt", params: valid_params.merge(force: "true"), headers: authorization_header
        expect(response).to have_http_status(:accepted)
      end
    end

    context "認証なし" do
      it "トークンもセッションもない場合401を返すこと" do
        post "/api/v1/receipts/process_receipt", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "セッション認証（Web UI）" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "Deviseセッション認証でAPIを利用できること" do
        post "/api/v1/receipts/process_receipt", params: valid_params
        expect(response).to have_http_status(:accepted)
      end
    end
  end

  describe "GET /api/v1/receipts/:id/status" do
    it "completedバッチのサマリーを返すこと" do
      batch = create(:statement_batch, :completed, client: client, source_type: "receipt")

      get "/api/v1/receipts/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("completed")
      expect(data["summary"]).to be_present
    end

    it "他テナントのバッチにアクセスできないこと" do
      other_client = create(:client, code: "other_client")
      batch = create(:statement_batch, client: other_client, source_type: "receipt")

      get "/api/v1/receipts/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header
      expect(response).to have_http_status(:not_found)
    end
  end
end
