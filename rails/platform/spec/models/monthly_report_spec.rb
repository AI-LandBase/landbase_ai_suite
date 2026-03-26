require "rails_helper"

RSpec.describe MonthlyReport, type: :model do
  describe "バリデーション" do
    it "有効なファクトリであること" do
      report = build(:monthly_report)
      expect(report).to be_valid
    end

    it "client が必須であること" do
      report = build(:monthly_report, client: nil)
      expect(report).not_to be_valid
      expect(report.errors[:client]).to be_present
    end

    it "year_month が必須であること" do
      report = build(:monthly_report, year_month: nil)
      expect(report).not_to be_valid
      expect(report.errors[:year_month]).to be_present
    end

    it "year_month がYYYY-MM形式でなければエラーになること" do
      report = build(:monthly_report, year_month: "202603")
      expect(report).not_to be_valid
      expect(report.errors[:year_month]).to be_present
    end

    it "year_month がYYYY-MM形式で有効であること" do
      report = build(:monthly_report, year_month: "2026-03")
      expect(report).to be_valid
    end

    it "content が必須であること" do
      report = build(:monthly_report, content: nil)
      expect(report).not_to be_valid
      expect(report.errors[:content]).to be_present
    end

    it "status が不正な値の場合バリデーションエラーになること" do
      report = build(:monthly_report, status: "invalid")
      expect(report).not_to be_valid
      expect(report.errors[:status]).to be_present
    end

    it "同一クライアント・年月の重複を許可しないこと" do
      client = create(:client)
      create(:monthly_report, client: client, year_month: "2026-03")
      duplicate = build(:monthly_report, client: client, year_month: "2026-03")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:year_month]).to be_present
    end

    it "異なるクライアントであれば同一年月を許可すること" do
      client_a = create(:client)
      client_b = create(:client)
      create(:monthly_report, client: client_a, year_month: "2026-03")
      report = build(:monthly_report, client: client_b, year_month: "2026-03")
      expect(report).to be_valid
    end
  end

  describe "スコープ" do
    describe ".for_client" do
      it "指定したclient_codeのレコードのみ返すこと" do
        client_a = create(:client, code: "report_a")
        client_b = create(:client, code: "report_b")
        report_a = create(:monthly_report, client: client_a, year_month: "2026-01")
        _report_b = create(:monthly_report, client: client_b, year_month: "2026-01")

        result = MonthlyReport.for_client("report_a")
        expect(result).to contain_exactly(report_a)
      end
    end

    describe ".recent" do
      it "year_monthの降順で返すこと" do
        client = create(:client)
        jan = create(:monthly_report, client: client, year_month: "2026-01")
        mar = create(:monthly_report, client: client, year_month: "2026-03")
        feb = create(:monthly_report, client: client, year_month: "2026-02")

        result = MonthlyReport.where(client: client).recent
        expect(result.to_a).to eq([ mar, feb, jan ])
      end
    end

    describe ".published" do
      it "公開済みのレコードのみ返すこと" do
        _draft = create(:monthly_report, status: "draft")
        published = create(:monthly_report, :published)

        result = MonthlyReport.published
        expect(result).to contain_exactly(published)
      end
    end
  end

  describe "#display_year_month" do
    it "YYYY年M月形式で返すこと" do
      report = build(:monthly_report, year_month: "2026-03")
      expect(report.display_year_month).to eq("2026年3月")
    end

    it "1月の場合ゼロ埋めなしで返すこと" do
      report = build(:monthly_report, year_month: "2026-01")
      expect(report.display_year_month).to eq("2026年1月")
    end
  end

  describe "#status_label" do
    it "draftの場合「下書き」を返すこと" do
      report = build(:monthly_report, status: "draft")
      expect(report.status_label).to eq("下書き")
    end

    it "publishedの場合「公開」を返すこと" do
      report = build(:monthly_report, status: "published")
      expect(report.status_label).to eq("公開")
    end
  end

  describe "マルチテナント分離" do
    it "異なるクライアントのデータが混在しないこと" do
      client_a = create(:client, code: "tenant_r_a")
      client_b = create(:client, code: "tenant_r_b")
      create(:monthly_report, client: client_a, year_month: "2026-01")
      create(:monthly_report, client: client_b, year_month: "2026-01")

      result = MonthlyReport.for_client("tenant_r_a")
      expect(result.size).to eq(1)
      expect(result.first.client).to eq(client_a)
    end
  end
end
