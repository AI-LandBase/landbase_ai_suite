require "rails_helper"

RSpec.describe "Api::V1::Invoices", type: :request do
  let(:client) { create(:client, code: "test_client") }
  let(:client_code) { client.code }
  let(:api_token_record) { create(:api_token) }
  let(:authorization_header) { { "Authorization" => "Bearer #{api_token_record.raw_token}" } }

  describe "POST /api/v1/invoices/process_statement" do
    let(:test_pdf) { fixture_file_upload("test_statement.pdf", "application/pdf") }
    let(:valid_params) do
      {
        client_code: client_code,
        pdf: test_pdf
      }
    end

    before do
      allow(InvoiceProcessJob).to receive(:perform_later)
    end

    it "202を返しジョブをエンキューすること" do
      post "/api/v1/invoices/process_statement", params: valid_params, headers: authorization_header

      expect(response).to have_http_status(:accepted)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("processing")
      expect(data["id"]).to be_present
      expect(InvoiceProcessJob).to have_received(:perform_later).with(anything)
      expect(StatementBatch.count).to eq(1)
      expect(StatementBatch.last.status).to eq("processing")
      expect(StatementBatch.last.source_type).to eq("invoice")
    end

    it "PDFがない場合エラーを返すこと" do
      post "/api/v1/invoices/process_statement", params: {
        client_code: client_code
      }, headers: authorization_header

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("PDF")
    end

    it "PDF以外のファイルの場合エラーを返すこと" do
      non_pdf = fixture_file_upload("test_image.jpg", "image/jpeg")

      post "/api/v1/invoices/process_statement", params: {
        client_code: client_code,
        pdf: non_pdf
      }, headers: authorization_header

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("PDF")
    end

    it "client_codeがない場合400を返すこと" do
      post "/api/v1/invoices/process_statement", params: { pdf: test_pdf }, headers: authorization_header

      expect(response).to have_http_status(:bad_request)
    end

    it "存在しないクライアントの場合404を返すこと" do
      post "/api/v1/invoices/process_statement", params: {
        client_code: "nonexistent",
        pdf: test_pdf
      }, headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end

    context "取り込み失敗 (issue#302)" do
      it "ingest! が IngestError を投げた場合、BaseController の rescue_from で422を返すこと" do
        allow(StatementBatch).to receive(:ingest!).and_raise(
          StatementBatch::IngestError.new("取り込みに失敗しました", cause_error: Errno::ENOSPC.new("No space left on device"))
        )

        post "/api/v1/invoices/process_statement", params: valid_params, headers: authorization_header

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to include("保存に失敗")
        expect(InvoiceProcessJob).not_to have_received(:perform_later)
      end
    end

    context "重複PDF検知" do
      it "同一PDFが処理済みの場合409を返すこと" do
        pdf_content = File.read(Rails.root.join("spec/fixtures/files/test_statement.pdf"))
        fingerprint = Digest::SHA256.hexdigest(pdf_content)
        create(:statement_batch, :completed, client: client, pdf_fingerprint: fingerprint)

        post "/api/v1/invoices/process_statement", params: valid_params, headers: authorization_header

        expect(response).to have_http_status(:conflict)
        data = JSON.parse(response.body)
        expect(data["duplicate"]).to be true
        expect(data["existing_batch_id"]).to be_present
        expect(data["error"]).to include("処理済み")
      end

      it "同一PDFが処理中の場合409を返すこと" do
        pdf_content = File.read(Rails.root.join("spec/fixtures/files/test_statement.pdf"))
        fingerprint = Digest::SHA256.hexdigest(pdf_content)
        create(:statement_batch, :processing, client: client, pdf_fingerprint: fingerprint)

        post "/api/v1/invoices/process_statement", params: valid_params, headers: authorization_header

        expect(response).to have_http_status(:conflict)
        data = JSON.parse(response.body)
        expect(data["duplicate"]).to be true
        expect(data["error"]).to include("処理中")
      end

      it "force: trueで重複チェックをスキップできること" do
        pdf_content = File.read(Rails.root.join("spec/fixtures/files/test_statement.pdf"))
        fingerprint = Digest::SHA256.hexdigest(pdf_content)
        create(:statement_batch, :completed, client: client, pdf_fingerprint: fingerprint)

        post "/api/v1/invoices/process_statement", params: valid_params.merge(force: "true"), headers: authorization_header

        expect(response).to have_http_status(:accepted)
        data = JSON.parse(response.body)
        expect(data["status"]).to eq("processing")
      end
    end
  end

  context "セッション認証（Web UI）" do
    let(:user) { create(:user) }
    let(:test_pdf) { fixture_file_upload("test_statement.pdf", "application/pdf") }

    before do
      sign_in user
      allow(InvoiceProcessJob).to receive(:perform_later)
    end

    it "Deviseセッション認証でAPIを利用できること" do
      post "/api/v1/invoices/process_statement", params: { client_code: client_code, pdf: test_pdf }
      expect(response).to have_http_status(:accepted)
    end

    it "ステータス確認もセッション認証で利用できること" do
      batch = create(:statement_batch, :processing, client: client)
      get "/api/v1/invoices/#{batch.id}/status", params: { client_code: client_code }
      expect(response).to have_http_status(:ok)
    end

    it "同一オリジンからのリクエストを許可すること" do
      post "/api/v1/invoices/process_statement",
        params: { client_code: client_code, pdf: test_pdf },
        headers: { "Origin" => "http://www.example.com" }
      expect(response).to have_http_status(:accepted)
    end

    it "異なるオリジンからのセッション認証リクエストを拒否すること" do
      post "/api/v1/invoices/process_statement",
        params: { client_code: client_code, pdf: test_pdf },
        headers: { "Origin" => "https://evil.example.com" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "認証なし" do
    let(:test_pdf) { fixture_file_upload("test_statement.pdf", "application/pdf") }

    it "トークンもセッションもない場合401を返すこと" do
      post "/api/v1/invoices/process_statement", params: { client_code: client_code, pdf: test_pdf }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "Bearerトークンとセッションの優先順位" do
    let(:user) { create(:user) }
    let(:test_pdf) { fixture_file_upload("test_statement.pdf", "application/pdf") }

    before do
      sign_in user
      allow(InvoiceProcessJob).to receive(:perform_later)
    end

    it "Bearerトークンがある場合はトークン認証が優先されること" do
      post "/api/v1/invoices/process_statement",
           params: { client_code: client_code, pdf: test_pdf },
           headers: authorization_header
      expect(response).to have_http_status(:accepted)
      expect(api_token_record.reload.last_used_at).to be_present
    end

    it "無効なBearerトークンの場合はセッションにフォールバックしないこと" do
      post "/api/v1/invoices/process_statement",
           params: { client_code: client_code, pdf: test_pdf },
           headers: { "Authorization" => "Bearer invalid_token" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/invoices/:id/status" do
    it "processing状態のバッチのステータスを返すこと" do
      batch = create(:statement_batch, :processing, client: client)

      get "/api/v1/invoices/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("processing")
      expect(data).not_to have_key("summary")
    end

    it "完了したバッチのサマリーを返すこと" do
      batch = create(:statement_batch, :completed, client: client)

      get "/api/v1/invoices/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("completed")
      expect(data["summary"]).to be_present
      expect(data["journal_entries_count"]).to eq(0)
    end

    it "失敗したバッチのエラーメッセージを返すこと" do
      batch = create(:statement_batch, :failed, client: client)

      get "/api/v1/invoices/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("failed")
      expect(data["error_message"]).to be_present
    end

    it "他テナントのバッチにアクセスできないこと" do
      other_client = create(:client, code: "other_client")
      batch = create(:statement_batch, client: other_client)

      get "/api/v1/invoices/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end

    it "存在しないIDの場合404を返すこと" do
      get "/api/v1/invoices/99999/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end
  end
end
