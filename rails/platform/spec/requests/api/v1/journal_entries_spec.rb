require "rails_helper"

RSpec.describe "Api::V1::JournalEntries", type: :request do
  let(:client) { create(:client, code: "test_client") }
  let(:client_code) { client.code }
  let(:api_token_record) { create(:api_token) }
  let(:authorization_header) { { "Authorization" => "Bearer #{api_token_record.raw_token}" } }

  describe "GET /api/v1/journal_entries" do
    it "client_codeがない場合400を返すこと" do
      get "/api/v1/journal_entries", headers: authorization_header
      expect(response).to have_http_status(:bad_request)
    end

    it "指定クライアントの仕訳一覧を返すこと" do
      other_client = create(:client, code: "other_client")
      create(:journal_entry, client: client, debit_account: "旅費交通費", debit_amount: 1000, credit_amount: 1000)
      create(:journal_entry, client: other_client, debit_account: "消耗品費", debit_amount: 2000, credit_amount: 2000)

      get "/api/v1/journal_entries", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["entries"].length).to eq(1)
      expect(data["entries"].first["debit_account"]).to eq("旅費交通費")
    end

    it "linesフィールドに仕訳行が含まれること" do
      create(:journal_entry, client: client, debit_account: "旅費交通費", credit_account: "未払金",
             debit_amount: 1000, credit_amount: 1000)

      get "/api/v1/journal_entries", params: { client_code: client_code }, headers: authorization_header

      data = JSON.parse(response.body)
      entry = data["entries"].first
      expect(entry["lines"].length).to eq(2)
      expect(entry["lines"].map { |l| l["side"] }).to contain_exactly("debit", "credit")
    end

    it "source_typeでフィルタできること" do
      create(:journal_entry, :amex, client: client, debit_amount: 1000, credit_amount: 1000)
      create(:journal_entry, :bank, client: client, debit_amount: 2000, credit_amount: 2000)

      get "/api/v1/journal_entries", params: { client_code: client_code, source_type: "amex" }, headers: authorization_header

      data = JSON.parse(response.body)
      expect(data["entries"].length).to eq(1)
      expect(data["entries"].first["source_type"]).to eq("amex")
    end

    it "review_requiredでフィルタできること" do
      create(:journal_entry, client: client, status: "ok", debit_amount: 1000, credit_amount: 1000)
      create(:journal_entry, :review_required, client: client, debit_amount: 2000, credit_amount: 2000)

      get "/api/v1/journal_entries", params: { client_code: client_code, review_required: "true" }, headers: authorization_header

      data = JSON.parse(response.body)
      expect(data["entries"].length).to eq(1)
      expect(data["entries"].first["status"]).to eq("review_required")
    end

    it "csv_export_status=unexported で未出力のみ返すこと" do
      create(:journal_entry, client: client, exported_at: nil,
             debit_account: "未出力", debit_amount: 1000, credit_amount: 1000)
      create(:journal_entry, client: client, exported_at: Time.current,
             debit_account: "出力済", debit_amount: 2000, credit_amount: 2000)

      get "/api/v1/journal_entries",
          params: { client_code: client_code, csv_export_status: "unexported" },
          headers: authorization_header

      data = JSON.parse(response.body)
      expect(data["entries"].length).to eq(1)
      expect(data["entries"].first["debit_account"]).to eq("未出力")
    end

    it "csv_export_status=exported で出力済みのみ返すこと" do
      create(:journal_entry, client: client, exported_at: nil,
             debit_account: "未出力", debit_amount: 1000, credit_amount: 1000)
      create(:journal_entry, client: client, exported_at: Time.current,
             debit_account: "出力済", debit_amount: 2000, credit_amount: 2000)

      get "/api/v1/journal_entries",
          params: { client_code: client_code, csv_export_status: "exported" },
          headers: authorization_header

      data = JSON.parse(response.body)
      expect(data["entries"].length).to eq(1)
      expect(data["entries"].first["debit_account"]).to eq("出力済")
    end

    it "日付範囲でフィルタできること" do
      create(:journal_entry, client: client, date: Date.new(2026, 1, 15), debit_amount: 1000, credit_amount: 1000)
      create(:journal_entry, client: client, date: Date.new(2025, 12, 1), debit_amount: 2000, credit_amount: 2000)

      get "/api/v1/journal_entries", params: {
        client_code: client_code,
        date_from: "2026-01-01",
        date_to: "2026-01-31"
      }, headers: authorization_header

      data = JSON.parse(response.body)
      expect(data["entries"].length).to eq(1)
    end

    it "ページネーションのメタ情報を返すこと" do
      create(:journal_entry, client: client, debit_amount: 1000, credit_amount: 1000)

      get "/api/v1/journal_entries", params: { client_code: client_code }, headers: authorization_header

      data = JSON.parse(response.body)
      expect(data["meta"]["current_page"]).to eq(1)
      expect(data["meta"]["total_pages"]).to eq(1)
      expect(data["meta"]["total_count"]).to eq(1)
    end

    it "per_pageパラメータでページサイズを変更できること" do
      3.times { create(:journal_entry, client: client, debit_amount: 1000, credit_amount: 1000) }

      get "/api/v1/journal_entries", params: { client_code: client_code, per_page: 2 }, headers: authorization_header

      data = JSON.parse(response.body)
      expect(data["entries"].length).to eq(2)
      expect(data["meta"]["current_page"]).to eq(1)
      expect(data["meta"]["total_pages"]).to eq(2)
      expect(data["meta"]["total_count"]).to eq(3)
    end

    it "pageパラメータで指定ページを取得できること" do
      3.times { create(:journal_entry, client: client, debit_amount: 1000, credit_amount: 1000) }

      get "/api/v1/journal_entries", params: { client_code: client_code, per_page: 2, page: 2 }, headers: authorization_header

      data = JSON.parse(response.body)
      expect(data["entries"].length).to eq(1)
      expect(data["meta"]["current_page"]).to eq(2)
    end
  end

  describe "GET /api/v1/journal_entries/:id" do
    it "仕訳詳細を返すこと" do
      entry = create(:journal_entry, client: client, debit_amount: 5000, credit_amount: 5000)

      get "/api/v1/journal_entries/#{entry.id}", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["id"]).to eq(entry.id)
      expect(data["debit_amount"]).to eq(5000)
      expect(data["lines"].length).to eq(2)
    end

    it "他テナントの仕訳にアクセスできないこと" do
      other_client = create(:client, code: "other_client")
      entry = create(:journal_entry, client: other_client, debit_amount: 1000, credit_amount: 1000)

      get "/api/v1/journal_entries/#{entry.id}", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/journal_entries/:id" do
    it "仕訳のヘッダー情報を更新できること" do
      entry = create(:journal_entry, client: client, debit_amount: 1000, credit_amount: 1000, status: "review_required")

      patch "/api/v1/journal_entries/#{entry.id}", params: {
        client_code: client_code,
        status: "ok",
        memo: "確認済み"
      }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["status"]).to eq("ok")
      expect(data["memo"]).to eq("確認済み")
    end

    it "他テナントの仕訳を更新できないこと" do
      other_client = create(:client, code: "other_client")
      entry = create(:journal_entry, client: other_client, debit_amount: 1000, credit_amount: 1000)

      patch "/api/v1/journal_entries/#{entry.id}", params: {
        client_code: client_code,
        status: "ok"
      }, headers: authorization_header

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/journal_entries/export" do
    it "CSV形式でエクスポートできること" do
      create(:journal_entry, client: client, transaction_no: 1, date: Date.new(2026, 1, 15),
             debit_account: "旅費交通費", credit_account: "未払金",
             debit_amount: 5000, credit_amount: 5000)

      get "/api/v1/journal_entries/export", params: { client_code: client_code }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")

      csv = CSV.parse(response.body.sub("\uFEFF", ""), headers: true)
      expect(csv.headers).to eq(JournalEntry::CSV_HEADERS)
      expect(csv.size).to eq(1)
    end

    it "source_typeでフィルタしてエクスポートできること" do
      create(:journal_entry, :amex, client: client, debit_amount: 1000, credit_amount: 1000)
      create(:journal_entry, :bank, client: client, debit_amount: 2000, credit_amount: 2000)

      get "/api/v1/journal_entries/export", params: { client_code: client_code, source_type: "amex" }, headers: authorization_header

      csv = CSV.parse(response.body.sub("\uFEFF", ""), headers: true)
      expect(csv.size).to eq(1)
    end

    it "from/toで期間フィルタできること" do
      create(:journal_entry, client: client, date: Date.new(2026, 1, 15), debit_amount: 1000, credit_amount: 1000)
      create(:journal_entry, client: client, date: Date.new(2025, 12, 1), debit_amount: 2000, credit_amount: 2000)

      get "/api/v1/journal_entries/export", params: {
        client_code: client_code, date_from: "2026-01-01", date_to: "2026-01-31"
      }, headers: authorization_header

      csv = CSV.parse(response.body.sub("\uFEFF", ""), headers: true)
      expect(csv.size).to eq(1)
    end

    it "format_type=yayoi_singleで弥生単一仕訳CSVをエクスポートできること" do
      create(:journal_entry, client: client, date: Date.new(2026, 1, 15),
             debit_account: "旅費交通費", credit_account: "未払金",
             debit_amount: 5000, credit_amount: 5000)

      get "/api/v1/journal_entries/export", params: {
        client_code: client_code, format_type: "yayoi_single"
      }, headers: authorization_header

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.content_type).to include("windows-31j")

      decoded = response.body.force_encoding("Windows-31J").encode("UTF-8")
      rows = CSV.parse(decoded)
      expect(rows.length).to eq(1)
      expect(rows[0].length).to eq(25)
      expect(rows[0][0]).to eq("2000")
      expect(rows[0][19]).to eq("0")
    end

  end
end
