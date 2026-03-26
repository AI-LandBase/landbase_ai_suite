require 'rails_helper'

RSpec.describe "Web::MonthlyReports", type: :request do
  let(:user) { create(:user) }
  let(:client) { create(:client, code: "mr_test") }

  describe "GET /monthly_reports" do
    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get monthly_reports_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "200を返すこと" do
        get monthly_reports_path(client_code: client.code)
        expect(response).to have_http_status(:ok)
      end

      it "クライアントのレポートのみ表示すること" do
        other_client = create(:client, code: "mr_other")
        report = create(:monthly_report, client: client, year_month: "2026-01")
        _other_report = create(:monthly_report, client: other_client, year_month: "2026-01")

        get monthly_reports_path(client_code: client.code)
        expect(response.body).to include("2026年1月")
      end
    end
  end

  describe "GET /monthly_reports/:id" do
    let(:report) { create(:monthly_report, client: client, year_month: "2026-02") }

    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get monthly_report_path(report, client_code: client.code)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "200を返すこと" do
        get monthly_report_path(report, client_code: client.code)
        expect(response).to have_http_status(:ok)
      end

      it "レポート内容がHTMLレンダリングされること" do
        get monthly_report_path(report, client_code: client.code)
        expect(response.body).to include("エグゼクティブサマリー")
      end

      it "他クライアントのレポートにはアクセスできないこと" do
        other_client = create(:client, code: "mr_other2")
        other_report = create(:monthly_report, client: other_client, year_month: "2026-03")

        get monthly_report_path(other_report, client_code: client.code)
        expect(response).to redirect_to(monthly_reports_path(client_code: client.code))
      end
    end
  end

  describe "POST /monthly_reports/generate" do
    context "認証済みの場合" do
      before { sign_in user }

      it "年月未指定の場合はリダイレクトすること" do
        post generate_monthly_reports_path(client_code: client.code, year_month: "")
        expect(response).to redirect_to(monthly_reports_path(client_code: client.code))
      end
    end
  end

  describe "DELETE /monthly_reports/:id" do
    let!(:report) { create(:monthly_report, client: client, year_month: "2026-04") }

    context "認証済みの場合" do
      before { sign_in user }

      it "レポートを削除すること" do
        expect {
          delete monthly_report_path(report, client_code: client.code)
        }.to change(MonthlyReport, :count).by(-1)
      end

      it "一覧にリダイレクトすること" do
        delete monthly_report_path(report, client_code: client.code)
        expect(response).to redirect_to(monthly_reports_path(client_code: client.code))
      end
    end
  end
end
