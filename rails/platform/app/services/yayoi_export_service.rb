require "csv"

class YayoiExportService
  SINGLE_ENTRY_FLAG = "2000"
  SINGLE_TYPE = "0"

  TAX_CATEGORY_STANDARD          = "課対仕入込10%"
  TAX_CATEGORY_REDUCED           = "課対仕入込軽減8%"
  TAX_CATEGORY_NON_TAXABLE_SALES = "非課売上"
  TAX_CATEGORY_OUT               = "対象外"

  def export_single_entry(entries)
    entries = entries.includes(:journal_entry_lines) if entries.respond_to?(:includes)

    csv_string = CSV.generate do |csv|
      entries.each do |entry|
        csv << build_row(entry)
      end
    end

    csv_string.encode("Windows-31J", "UTF-8", undef: :replace, invalid: :replace)
  end

  private

  def build_row(entry)
    debit  = entry.debit_lines.first
    credit = entry.credit_lines.first

    [
      SINGLE_ENTRY_FLAG,                       # 1: 識別フラグ
      entry.date.strftime("%Y/%m/%d"),         # 2: 取引日
      debit&.account || "",                     # 3: 借方勘定科目
      debit&.sub_account&.presence || "",      # 4: 借方補助科目
      debit&.department&.presence || "",       # 5: 借方部門
      debit&.partner&.presence || "",          # 6: 借方取引先
      map_tax_category(debit&.tax_category),   # 7: 借方税区分
      debit&.invoice&.presence || "",          # 8: 借方インボイス
      debit&.amount || 0,                      # 9: 借方金額
      credit&.account || "",                   # 10: 貸方勘定科目
      credit&.sub_account&.presence || "",     # 11: 貸方補助科目
      credit&.department&.presence || "",      # 12: 貸方部門
      credit&.partner&.presence || "",         # 13: 貸方取引先
      map_tax_category(credit&.tax_category),  # 14: 貸方税区分
      credit&.invoice&.presence || "",         # 15: 貸方インボイス
      credit&.amount || 0,                     # 16: 貸方金額
      entry.description.presence || "",        # 17: 摘要
      entry.tag.presence || "",                # 18: タグ
      entry.memo.presence || "",               # 19: メモ
      SINGLE_TYPE,                             # 20: タイプ
      "",                                      # 21: 調整フラグ
      "",                                      # 22: 予備1
      "",                                      # 23: 予備2
      "",                                      # 24: 予備3
      ""                                       # 25: 予備4
    ]
  end

  # クレカ明細等は適格／非適格の判定不能のため、課税仕入はすべて適格扱いで弥生の課対仕入区分に丸める。
  # 非課税「売上」（受取利息など）は弥生では「非課売上」が正しく、課税売上割合の按分計算に影響するため
  # 「対象外」とは区別する。一方、非課税「仕入」・不課税・リバースチャージは弥生公式案内に従い「対象外」に集約する。
  #   参考: https://support.yayoi-kk.co.jp/faq_Subcontents.html?page_id=27344
  # 空文字は弥生で「税区分なし」を意味するため、そのまま空文字で返す。
  def map_tax_category(raw)
    return "" if raw.blank?

    if raw.include?("非課税売上") || raw.include?("非課売上")
      TAX_CATEGORY_NON_TAXABLE_SALES
    elsif raw.include?("軽減") || raw.include?("8%")
      TAX_CATEGORY_REDUCED
    elsif raw.include?("10%")
      TAX_CATEGORY_STANDARD
    else
      TAX_CATEGORY_OUT
    end
  end
end
