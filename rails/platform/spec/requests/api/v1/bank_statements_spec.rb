require "rails_helper"

RSpec.describe "Api::V1::BankStatements", type: :request do
  let(:client) { create(:client, code: "test_client") }
  let(:client_code) { client.code }
  let(:api_token_record) { create(:api_token) }
  let(:authorization_header) { { "Authorization" => "Bearer #{api_token_record.raw_token}" } }

  describe "POST /api/v1/bank_statements/process_statement" do
    let(:test_pdf) { fixture_file_upload("test_statement.pdf", "application/pdf") }
    let(:valid_params) do
      {
        client_code: client_code,
        pdf: test_pdf
      }
    end

    before do
      allow(BankStatementProcessJob).to receive(:perform_later)
    end

    it "202を返しジョブをエンキューすること" do
      post "/api/v1/bank_statements/process_statement", params: valid_params, headers: authorization_header

      expect(response).to have_http_status(:accepted)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("processing")
      expect(data["id"]).to be_present
      expect(BankStatementProcessJob).to have_received(:perform_later).with(anything)
      expect(StatementBatch.count).to eq(1)
      expect(StatementBatch.last.status).to eq("processing")
      expect(StatementBatch.last.source_type).to eq("bank")
    end

    it "PDFがない場合エラーを返すこと" do
      post "/api/v1/bank_statements/process_statement", params: {
        client_code: client_code
      }, headers: authorization_header

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("PDF")
    end

    it "PDF以外のファイルの場合エラーを返すこと" do
      non_pdf = fixture_file_upload("test_image.jpg", "image/jpeg")

      post "/api/v1/bank_statements/process_statement", params: {
        client_code: client_code,
        pdf: non_pdf
      }, headers: authorization_header

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("PDF")
    end

    it "client_codeがない場合400を返すこと" do
      post "/api/v1/bank_statements/process_statement", params: { pdf: test_pdf }, headers: authorization_header

      expect(response).to have_http_status(:bad_request)
    end

    it "存在しないクライアントの場合404を返すこと" do
      post "/api/v1/bank_statements/process_statement", params: {
        client_code: "nonexistent",
        pdf: test_pdf
      }, headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end

    context "重複PDF検知" do
      it "同一PDFが処理済みの場合409を返すこと" do
        pdf_content = File.read(Rails.root.join("spec/fixtures/files/test_statement.pdf"))
        fingerprint = Digest::SHA256.hexdigest(pdf_content)
        create(:statement_batch, :completed, client: client, pdf_fingerprint: fingerprint)

        post "/api/v1/bank_statements/process_statement", params: valid_params, headers: authorization_header

        expect(response).to have_http_status(:conflict)
        data = JSON.parse(response.body)
        expect(data["duplicate"]).to be true
        expect(data["existing_batch_id"]).to be_present
        expect(data["error"]).to include("処理済み")
      end

      it "409に処理済みバッチへのURLが含まれること (issue#307)" do
        pdf_content = File.read(Rails.root.join("spec/fixtures/files/test_statement.pdf"))
        fingerprint = Digest::SHA256.hexdigest(pdf_content)
        existing = create(:statement_batch, :completed, client: client, pdf_fingerprint: fingerprint)

        post "/api/v1/bank_statements/process_statement", params: valid_params, headers: authorization_header

        data = JSON.parse(response.body)
        expect(data["existing_batch_url"]).to eq("/statement_batches/#{existing.id}")
      end

      it "取り込み成功時に同一fingerprintのfailedバッチを掃除すること (issue#307)" do
        pdf_content = File.read(Rails.root.join("spec/fixtures/files/test_statement.pdf"))
        fingerprint = Digest::SHA256.hexdigest(pdf_content)
        stale = create(:statement_batch, :failed, client: client, pdf_fingerprint: fingerprint)

        post "/api/v1/bank_statements/process_statement", params: valid_params, headers: authorization_header

        expect(response).to have_http_status(:accepted)
        expect(StatementBatch.exists?(stale.id)).to be false
      end

      it "他テナントの同一fingerprintのfailedバッチは掃除しないこと (issue#307)" do
        other_client = create(:client, code: "other_client")
        pdf_content = File.read(Rails.root.join("spec/fixtures/files/test_statement.pdf"))
        fingerprint = Digest::SHA256.hexdigest(pdf_content)
        other_stale = create(:statement_batch, :failed, client: other_client, pdf_fingerprint: fingerprint)

        post "/api/v1/bank_statements/process_statement", params: valid_params, headers: authorization_header

        expect(response).to have_http_status(:accepted)
        expect(StatementBatch.exists?(other_stale.id)).to be true
      end

      it "同一PDFが処理中の場合409を返すこと" do
        pdf_content = File.read(Rails.root.join("spec/fixtures/files/test_statement.pdf"))
        fingerprint = Digest::SHA256.hexdigest(pdf_content)
        create(:statement_batch, :processing, client: client, pdf_fingerprint: fingerprint)

        post "/api/v1/bank_statements/process_statement", params: valid_params, headers: authorization_header

        expect(response).to have_http_status(:conflict)
        data = JSON.parse(response.body)
        expect(data["duplicate"]).to be true
        expect(data["error"]).to include("処理中")
      end

      it "force: trueで重複チェックをスキップできること" do
        pdf_content = File.read(Rails.root.join("spec/fixtures/files/test_statement.pdf"))
        fingerprint = Digest::SHA256.hexdigest(pdf_content)
        create(:statement_batch, :completed, client: client, pdf_fingerprint: fingerprint)

        post "/api/v1/bank_statements/process_statement", params: valid_params.merge(force: "true"), headers: authorization_header

        expect(response).to have_http_status(:accepted)
        data = JSON.parse(response.body)
        expect(data["status"]).to eq("processing")
      end
    end
  end

  describe "GET /api/v1/bank_statements/:id/status" do
    it "processing状態のバッチのステータスを返すこと" do
      batch = create(:statement_batch, :processing, client: client)

      get "/api/v1/bank_statements/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("processing")
      expect(data).not_to have_key("summary")
    end

    it "完了したバッチのサマリーを返すこと" do
      batch = create(:statement_batch, :completed, client: client)

      get "/api/v1/bank_statements/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("completed")
      expect(data["summary"]).to be_present
      expect(data["journal_entries_count"]).to eq(0)
    end

    it "失敗したバッチのエラーメッセージを返すこと" do
      batch = create(:statement_batch, :failed, client: client)

      get "/api/v1/bank_statements/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("failed")
      expect(data["error_message"]).to be_present
    end

    it "他テナントのバッチにアクセスできないこと" do
      other_client = create(:client, code: "other_client")
      batch = create(:statement_batch, client: other_client)

      get "/api/v1/bank_statements/#{batch.id}/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end

    it "存在しないIDの場合404を返すこと" do
      get "/api/v1/bank_statements/99999/status", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end
  end
end
