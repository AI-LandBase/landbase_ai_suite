require "rails_helper"

RSpec.describe JournalEntry, type: :model do
  describe "バリデーション" do
    subject { build(:journal_entry) }

    describe "必須カラム" do
      it "有効なファクトリが正常に動作する" do
        expect(subject).to be_valid
      end

      it "clientが空の場合無効" do
        subject.client = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:client]).to be_present
      end

      it "dateが空の場合無効" do
        subject.date = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:date]).to be_present
      end
    end

    describe "source_type" do
      %w[amex bank invoice receipt].each do |valid_type|
        it "#{valid_type}は有効" do
          subject.source_type = valid_type
          expect(subject).to be_valid
        end
      end

      it "無効なsource_typeの場合エラー" do
        subject.source_type = "invalid"
        expect(subject).not_to be_valid
        expect(subject.errors[:source_type]).to be_present
      end
    end

    describe "status" do
      %w[ok review_required].each do |valid_status|
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

    describe "貸借一致バリデーション" do
      it "借方合計と貸方合計が一致する場合有効" do
        entry = build(:journal_entry, debit_amount: 1000, credit_amount: 1000)
        expect(entry).to be_valid
      end

      it "借方合計と貸方合計が不一致の場合無効" do
        entry = build(:journal_entry, debit_amount: 1000, credit_amount: 2000)
        expect(entry).not_to be_valid
        expect(entry.errors[:base]).to be_present
      end

      it "金額0の場合有効（調整仕訳対応）" do
        entry = build(:journal_entry, debit_amount: 0, credit_amount: 0)
        expect(entry).to be_valid
      end
    end
  end

  describe "関連" do
    it "journal_entry_linesを持つ" do
      entry = create(:journal_entry, debit_amount: 5000, credit_amount: 5000)
      expect(entry.journal_entry_lines.count).to eq(2)
    end

    it "削除時にjournal_entry_linesも削除される" do
      entry = create(:journal_entry, debit_amount: 5000, credit_amount: 5000)
      expect { entry.destroy }.to change(JournalEntryLine, :count).by(-2)
    end
  end

  describe "便利メソッド" do
    let(:entry) { create(:journal_entry, debit_amount: 5000, credit_amount: 5000, debit_account: "旅費交通費", credit_account: "未払金") }

    it "#debit_linesが借方行を返す" do
      expect(entry.debit_lines.size).to eq(1)
      expect(entry.debit_lines.first.side).to eq("debit")
      expect(entry.debit_lines.first.account).to eq("旅費交通費")
    end

    it "#credit_linesが貸方行を返す" do
      expect(entry.credit_lines.size).to eq(1)
      expect(entry.credit_lines.first.side).to eq("credit")
      expect(entry.credit_lines.first.account).to eq("未払金")
    end

    it "#debit_amountが借方合計を返す" do
      expect(entry.debit_amount).to eq(5000)
    end

    it "#credit_amountが貸方合計を返す" do
      expect(entry.credit_amount).to eq(5000)
    end

    it "#simple_entry?が単一仕訳でtrueを返す" do
      expect(entry.simple_entry?).to be true
    end
  end

  describe "#revision_snapshot" do
    let(:entry) do
      create(:journal_entry, description: "テスト摘要", tag: "amex", memo: "メモ",
             cardholder: "山田太郎", status: "ok",
             debit_account: "旅費交通費", debit_amount: 5000,
             credit_account: "未払金", credit_amount: 5000)
    end

    it "日本語ラベルをキーとしたフラットなスナップショットを返すこと" do
      snap = entry.revision_snapshot

      expect(snap["摘要"]).to eq("テスト摘要")
      expect(snap["メモ"]).to eq("メモ")
      expect(snap["カード利用者"]).to eq("山田太郎")
      expect(snap["ステータス"]).to eq("OK")
      expect(snap["借方_勘定科目"]).to eq("旅費交通費")
      expect(snap["借方_金額"]).to eq("5000")
      expect(snap["貸方_勘定科目"]).to eq("未払金")
    end

    it "ステータスは日本語ラベルに変換されること" do
      entry.update!(status: "review_required")
      expect(entry.revision_snapshot["ステータス"]).to eq("要確認")
    end
  end

  describe "複合仕訳" do
    it "3行以上の仕訳を作成できる" do
      client = create(:client)
      entry = JournalEntry.create!(
        client: client,
        source_type: "bank",
        date: Date.current,
        description: "給与支払い",
        journal_entry_lines_attributes: [
          { side: "debit", account: "給与手当", amount: 300_000 },
          { side: "credit", account: "普通預金", amount: 250_000 },
          { side: "credit", account: "所得税預り金", amount: 30_000 },
          { side: "credit", account: "社会保険料預り金", amount: 20_000 }
        ]
      )

      expect(entry.journal_entry_lines.count).to eq(4)
      expect(entry.debit_amount).to eq(300_000)
      expect(entry.credit_amount).to eq(300_000)
      expect(entry.simple_entry?).to be false
    end

    it "貸借不一致の複合仕訳は無効" do
      client = create(:client)
      entry = JournalEntry.new(
        client: client,
        source_type: "bank",
        date: Date.current,
        journal_entry_lines_attributes: [
          { side: "debit", account: "給与手当", amount: 300_000 },
          { side: "credit", account: "普通預金", amount: 200_000 }
        ]
      )
      expect(entry).not_to be_valid
      expect(entry.errors[:base]).to be_present
    end
  end

  describe "スコープ" do
    describe ".for_client" do
      it "指定クライアントの仕訳のみ取得する" do
        client_a = create(:client, code: "client_a")
        client_b = create(:client, code: "client_b")
        entry_a = create(:journal_entry, client: client_a)
        create(:journal_entry, client: client_b)

        result = described_class.for_client("client_a")
        expect(result).to contain_exactly(entry_a)
      end
    end

    describe ".by_source" do
      it "指定source_typeの仕訳のみ取得する" do
        amex_entry = create(:journal_entry, :amex)
        create(:journal_entry, :bank)

        result = described_class.by_source("amex")
        expect(result).to contain_exactly(amex_entry)
      end
    end

    describe ".review_required" do
      it "review_requiredステータスの仕訳のみ取得する" do
        review_entry = create(:journal_entry, :review_required)
        create(:journal_entry, status: "ok")

        result = described_class.review_required
        expect(result).to contain_exactly(review_entry)
      end
    end

    describe ".in_period" do
      it "指定期間内の仕訳のみ取得する" do
        in_range = create(:journal_entry, date: Date.new(2026, 1, 15))
        create(:journal_entry, date: Date.new(2025, 12, 1))

        result = described_class.in_period(Date.new(2026, 1, 1), Date.new(2026, 1, 31))
        expect(result).to contain_exactly(in_range)
      end
    end

    describe ".csv_unexported" do
      it "exported_atがNULLの仕訳のみ取得する" do
        unexported = create(:journal_entry, exported_at: nil)
        create(:journal_entry, exported_at: Time.current)

        result = described_class.csv_unexported
        expect(result).to contain_exactly(unexported)
      end
    end

    describe ".csv_exported" do
      it "exported_atが入っている仕訳のみ取得する" do
        exported = create(:journal_entry, exported_at: Time.current)
        create(:journal_entry, exported_at: nil)

        result = described_class.csv_exported
        expect(result).to contain_exactly(exported)
      end
    end
  end

  describe ".to_csv" do
    it "単一仕訳がCSV形式でエクスポートされる" do
      create(:journal_entry, transaction_no: 1, date: Date.new(2026, 1, 15),
             debit_account: "旅費交通費", credit_account: "未払金",
             debit_amount: 5000, credit_amount: 5000, status: "ok")

      csv_string = described_class.to_csv
      csv = CSV.parse(csv_string, headers: true)

      expect(csv.headers).to eq(JournalEntry::CSV_HEADERS)
      expect(csv.size).to eq(1)
      expect(csv.first["取引No"]).to eq("1")
      expect(csv.first["取引日"]).to eq("2026-01-15")
      expect(csv.first["借方勘定科目"]).to eq("旅費交通費")
      expect(csv.first["貸方勘定科目"]).to eq("未払金")
      expect(csv.first["借方金額(円)"]).to eq("5000")
      expect(csv.first["ステータス"]).to eq("ok")
    end

    it "複合仕訳の全行がCSVに出力される" do
      client = create(:client)
      JournalEntry.create!(
        client: client,
        source_type: "bank",
        transaction_no: 1,
        date: Date.new(2026, 1, 20),
        description: "給与支払い",
        status: "ok",
        journal_entry_lines_attributes: [
          { side: "debit", account: "給与手当", amount: 300_000 },
          { side: "credit", account: "普通預金", amount: 250_000 },
          { side: "credit", account: "所得税預り金", amount: 30_000 },
          { side: "credit", account: "社会保険料預り金", amount: 20_000 }
        ]
      )

      csv_string = described_class.to_csv
      csv = CSV.parse(csv_string, headers: true)

      expect(csv.size).to eq(3)
      expect(csv[0]["借方勘定科目"]).to eq("給与手当")
      expect(csv[0]["貸方勘定科目"]).to eq("普通預金")
      expect(csv[0]["摘要"]).to eq("給与支払い")
      expect(csv[1]["借方勘定科目"]).to be_nil
      expect(csv[1]["貸方勘定科目"]).to eq("所得税預り金")
      expect(csv[1]["摘要"]).to eq("")
      expect(csv[2]["貸方勘定科目"]).to eq("社会保険料預り金")
    end
  end

  describe "マルチテナント分離" do
    it "異なるクライアントのデータが混在しない" do
      client_a = create(:client, code: "client_a")
      client_b = create(:client, code: "client_b")
      create(:journal_entry, client: client_a, debit_amount: 1000, credit_amount: 1000)
      create(:journal_entry, client: client_b, debit_amount: 2000, credit_amount: 2000)

      client_a_entries = described_class.for_client("client_a")
      client_b_entries = described_class.for_client("client_b")

      expect(client_a_entries.count).to eq(1)
      expect(client_b_entries.count).to eq(1)
      expect(client_a_entries.first.debit_amount).to eq(1000)
      expect(client_b_entries.first.debit_amount).to eq(2000)
    end
  end
end
