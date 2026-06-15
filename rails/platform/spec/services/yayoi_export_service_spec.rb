require "rails_helper"

RSpec.describe YayoiExportService do
  let(:client) { create(:client) }
  let(:service) { described_class.new }

  let!(:entry1) do
    create(:journal_entry, client: client,
           date: Date.new(2026, 1, 15), transaction_no: 1,
           debit_account: "旅費交通費", debit_sub_account: "", debit_department: "",
           debit_partner: "テスト株式会社", debit_tax_category: "課税仕入10%", debit_invoice: "T1234567890123",
           debit_amount: 10_000, credit_account: "未払金", credit_sub_account: "", credit_department: "",
           credit_partner: "", credit_tax_category: "", credit_invoice: "",
           credit_amount: 10_000, description: "出張旅費", tag: "", memo: "")
  end

  let!(:entry2) do
    create(:journal_entry, client: client,
           date: Date.new(2026, 1, 20), transaction_no: 2,
           debit_account: "消耗品費", debit_sub_account: "", debit_department: "",
           debit_partner: "", debit_tax_category: "課税仕入10%", debit_invoice: "",
           debit_amount: 5_000, credit_account: "現金", credit_sub_account: "", credit_department: "",
           credit_partner: "", credit_tax_category: "", credit_invoice: "",
           credit_amount: 5_000, description: "事務用品", tag: "", memo: "")
  end

  let(:entries) { client.journal_entries.order(date: :asc) }

  def decode_csv(csv_data)
    CSV.parse(csv_data.encode("UTF-8", "Windows-31J"))
  end

  describe "#export_single_entry" do
    let(:rows) { decode_csv(service.export_single_entry(entries)) }

    it "25列のCSVを生成すること" do
      rows.each { |row| expect(row.length).to eq(25) }
    end

    it "識別フラグが2000であること" do
      rows.each { |row| expect(row[0]).to eq("2000") }
    end

    it "タイプが0であること" do
      rows.each { |row| expect(row[19]).to eq("0") }
    end

    it "取引日がYYYY/MM/DD形式であること" do
      expect(rows[0][1]).to eq("2026/01/15")
      expect(rows[1][1]).to eq("2026/01/20")
    end

    it "金額フィールドが正しいこと" do
      expect(rows[0][8]).to eq("10000")
      expect(rows[0][15]).to eq("10000")
    end

    it "ヘッダ行がないこと" do
      expect(rows.length).to eq(2)
    end

    it "予備列が空文字であること" do
      rows.each do |row|
        (20..24).each { |i| expect(row[i]).to eq("") }
      end
    end
  end

  describe "Windows-31Jエンコーディング" do
    it "Windows-31Jでエンコードされていること" do
      csv_data = service.export_single_entry(entries)
      expect(csv_data.encoding).to eq(Encoding::Windows_31J)
    end

    it "日本語が正しくエンコードされること" do
      csv_data = service.export_single_entry(entries)
      decoded = csv_data.encode("UTF-8", "Windows-31J")
      expect(decoded).to include("旅費交通費")
      expect(decoded).to include("出張旅費")
    end
  end

  describe "空フィールドの扱い" do
    it "空文字フィールドが空文字のまま出力されること" do
      rows = decode_csv(service.export_single_entry(entries))
      expect(rows[1][5]).to eq("")
    end

    it "金額が0の場合0が出力されること" do
      entry = create(:journal_entry, client: client, debit_amount: 0, credit_amount: 0,
                     date: Date.new(2026, 2, 1))
      rows = decode_csv(service.export_single_entry(JournalEntry.where(id: entry.id)))
      expect(rows[0][8]).to eq("0")
      expect(rows[0][15]).to eq("0")
    end
  end

  describe "税区分マッピング (適格扱い3区分への統一)" do
    def build_entry(debit_tax:, credit_tax: "", date: Date.new(2026, 3, 1))
      create(:journal_entry, client: client, date: date,
             debit_account: "消耗品費", debit_tax_category: debit_tax, debit_amount: 1_000,
             credit_account: "未払金", credit_tax_category: credit_tax, credit_amount: 1_000)
    end

    def export_row(entry)
      decode_csv(service.export_single_entry(JournalEntry.where(id: entry.id))).first
    end

    it "「課税仕入10%（インボイス）」を「課対仕入込10%」に変換すること" do
      entry = build_entry(debit_tax: "課税仕入10%（インボイス）")
      expect(export_row(entry)[6]).to eq("課対仕入込10%")
    end

    it "「課税仕入10%（非インボイス）」を「課対仕入込10%」に変換すること" do
      entry = build_entry(debit_tax: "課税仕入10%（非インボイス）")
      expect(export_row(entry)[6]).to eq("課対仕入込10%")
    end

    it "「課税仕入10%」を「課対仕入込10%」に変換すること" do
      entry = build_entry(debit_tax: "課税仕入10%")
      expect(export_row(entry)[6]).to eq("課対仕入込10%")
    end

    it "「課税仕入8%（軽減・インボイス）」を「課対仕入込軽減8%」に変換すること" do
      entry = build_entry(debit_tax: "課税仕入8%（軽減・インボイス）")
      expect(export_row(entry)[6]).to eq("課対仕入込軽減8%")
    end

    it "「課税仕入8%（軽減・非インボイス）」を「課対仕入込軽減8%」に変換すること" do
      entry = build_entry(debit_tax: "課税仕入8%（軽減・非インボイス）")
      expect(export_row(entry)[6]).to eq("課対仕入込軽減8%")
    end

    it "「対象外」をそのまま「対象外」とすること" do
      entry = build_entry(debit_tax: "対象外")
      expect(export_row(entry)[6]).to eq("対象外")
    end

    it "「非課税仕入」を「対象外」に丸めること" do
      entry = build_entry(debit_tax: "非課税仕入")
      expect(export_row(entry)[6]).to eq("対象外")
    end

    it "「課対仕入（リバースチャージ）」を「対象外」に丸めること" do
      entry = build_entry(debit_tax: "課対仕入（リバースチャージ）")
      expect(export_row(entry)[6]).to eq("対象外")
    end

    it "空文字は空文字のまま出力されること（貸方など）" do
      entry = build_entry(debit_tax: "課税仕入10%", credit_tax: "")
      row = export_row(entry)
      expect(row[6]).to eq("課対仕入込10%")
      expect(row[13]).to eq("")
    end
  end
end
