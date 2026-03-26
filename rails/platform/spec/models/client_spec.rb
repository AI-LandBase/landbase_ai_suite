require "rails_helper"

RSpec.describe Client, type: :model do
  describe "バリデーション" do
    subject { build(:client) }

    describe "必須カラム" do
      it "有効なファクトリが正常に動作する" do
        expect(subject).to be_valid
      end

      it "codeが空の場合無効" do
        subject.code = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:code]).to be_present
      end

      it "nameが空の場合無効" do
        subject.name = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:name]).to be_present
      end
    end

    describe "code" do
      it "重複する場合無効" do
        create(:client, code: "duplicate_code")
        subject.code = "duplicate_code"
        expect(subject).not_to be_valid
        expect(subject.errors[:code]).to be_present
      end
    end

    describe "status" do
      %w[active trial inactive].each do |valid_status|
        it "#{valid_status}は有効" do
          subject.status = valid_status
          expect(subject).to be_valid
        end
      end

      it "無効なstatusの場合エラー" do
        subject.status = "invalid"
        expect(subject).not_to be_valid
        expect(subject.errors[:status]).to be_present
      end
    end

    describe "industry" do
      Client::INDUSTRIES.each_key do |valid_industry|
        it "#{valid_industry}は有効" do
          subject.industry = valid_industry
          expect(subject).to be_valid
        end
      end

      it "nilは有効" do
        subject.industry = nil
        expect(subject).to be_valid
      end

      it "旧値hotelは無効" do
        subject.industry = "hotel"
        expect(subject).not_to be_valid
      end

      it "旧値tourは無効" do
        subject.industry = "tour"
        expect(subject).not_to be_valid
      end

      it "無効なindustryの場合エラー" do
        subject.industry = "invalid"
        expect(subject).not_to be_valid
        expect(subject.errors[:industry]).to be_present
      end
    end
  end

  describe "#to_param" do
    it "codeを返す" do
      client = build(:client, code: "my_code")
      expect(client.to_param).to eq("my_code")
    end
  end

  describe "#status_label" do
    it "activeは「有効」を返す" do
      expect(build(:client, status: "active").status_label).to eq("有効")
    end

    it "trialは「トライアル」を返す" do
      expect(build(:client, status: "trial").status_label).to eq("トライアル")
    end

    it "inactiveは「無効」を返す" do
      expect(build(:client, status: "inactive").status_label).to eq("無効")
    end
  end

  describe "STATUSES" do
    it "全ステータスが定義されている" do
      expect(Client::STATUSES.keys).to contain_exactly("active", "trial", "inactive")
    end
  end

  describe "INDUSTRIES" do
    it "全業種が定義されている" do
      expect(Client::INDUSTRIES.keys).to contain_exactly(
        "accommodation", "restaurant", "activity", "retail", "rental_car", "beauty", "other"
      )
    end
  end

  describe "#industry_label" do
    it "accommodationは「宿泊業」を返す" do
      expect(build(:client, industry: "accommodation").industry_label).to eq("宿泊業")
    end

    it "restaurantは「飲食業」を返す" do
      expect(build(:client, industry: "restaurant").industry_label).to eq("飲食業")
    end

    it "activityは「アクティビティ」を返す" do
      expect(build(:client, industry: "activity").industry_label).to eq("アクティビティ")
    end

    it "nilの場合はnilを返す" do
      expect(build(:client, industry: nil).industry_label).to be_nil
    end
  end

  describe "スコープ" do
    describe ".active" do
      it "activeステータスのクライアントのみ取得する" do
        active_client = create(:client, status: "active")
        create(:client, status: "inactive")

        result = described_class.active
        expect(result).to contain_exactly(active_client)
      end
    end

    describe ".visible" do
      it "activeとtrialのクライアントを取得する" do
        active_client = create(:client, status: "active")
        trial_client = create(:client, status: "trial")
        create(:client, status: "inactive")

        result = described_class.visible
        expect(result).to contain_exactly(active_client, trial_client)
      end
    end

    describe ".search" do
      let!(:ikigai) { create(:client, code: "ikigai_stay", name: "イキガイステイ") }
      let!(:oku) { create(:client, code: "oku_resort", name: "奥リゾート") }

      it "コードで部分一致検索できる" do
        expect(described_class.search("ikigai")).to contain_exactly(ikigai)
      end

      it "名前で部分一致検索できる" do
        expect(described_class.search("リゾート")).to contain_exactly(oku)
      end

      it "大文字小文字を区別しない" do
        expect(described_class.search("IKIGAI")).to contain_exactly(ikigai)
      end

      it "空文字列の場合は全件返す" do
        expect(described_class.search("")).to contain_exactly(ikigai, oku)
      end

      it "nilの場合は全件返す" do
        expect(described_class.search(nil)).to contain_exactly(ikigai, oku)
      end

      it "SQLインジェクションを防ぐ（%や_をエスケープ）" do
        expect(described_class.search("100%")).to be_empty
      end
    end
  end

  describe "関連" do
    let!(:client) { create(:client) }

    it "journal_entriesを持てる" do
      entry = create(:journal_entry, client: client)
      expect(client.journal_entries).to contain_exactly(entry)
    end

    it "account_mastersを持てる" do
      master = create(:account_master, client: client)
      expect(client.account_masters).to contain_exactly(master)
    end
  end

  describe "#feature_available?" do
    describe "業種デフォルト" do
      it "hotelクライアントはcleaning_manualsが利用可能" do
        client = build(:client, :hotel, services: {})
        expect(client.feature_available?(:cleaning_manuals)).to be true
      end

      it "restaurantクライアントはcleaning_manualsが利用不可" do
        client = build(:client, industry: "restaurant", services: {})
        expect(client.feature_available?(:cleaning_manuals)).to be false
      end

      it "activityクライアントはcleaning_manualsが利用不可" do
        client = build(:client, industry: "activity", services: {})
        expect(client.feature_available?(:cleaning_manuals)).to be false
      end

      it "industry未設定のクライアントはcleaning_manualsが利用不可" do
        client = build(:client, industry: nil, services: {})
        expect(client.feature_available?(:cleaning_manuals)).to be false
      end
    end

    describe "servicesオーバーライド" do
      it "servicesでtrueに設定するとrestaurantでも利用可能" do
        client = build(:client, industry: "restaurant", services: { "cleaning_manuals" => true })
        expect(client.feature_available?(:cleaning_manuals)).to be true
      end

      it "servicesでfalseに設定するとhotelでも利用不可" do
        client = build(:client, :hotel, services: { "cleaning_manuals" => false })
        expect(client.feature_available?(:cleaning_manuals)).to be false
      end
    end

    describe "引数の型" do
      it "Symbolでも動作する" do
        client = build(:client, :hotel)
        expect(client.feature_available?(:cleaning_manuals)).to be true
      end

      it "Stringでも動作する" do
        client = build(:client, :hotel)
        expect(client.feature_available?("cleaning_manuals")).to be true
      end
    end
  end
end
