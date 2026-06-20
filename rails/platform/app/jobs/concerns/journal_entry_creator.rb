module JournalEntryCreator
  extend ActiveSupport::Concern

  class DuplicateFound < StandardError
    attr_reader :existing_entry

    def initialize(existing_entry)
      @existing_entry = existing_entry
      super("duplicate receipt")
    end
  end

  private

  def create_journal_entries(batch, data)
    source_period = resolve_source_period(batch, data)
    transactions = data[:transactions] || []

    if batch.source_type == "receipt"
      existing = find_duplicate_receipt(batch.client, transactions)
      raise DuplicateFound.new(existing) if existing
    end

    base_txn_no = batch.client.journal_entries
                       .where(source_type: batch.source_type, source_period: source_period)
                       .maximum(:transaction_no).to_i

    transactions.each_with_index do |txn, idx|
      batch.journal_entries.create!(
        client: batch.client,
        source_type: batch.source_type,
        source_period: source_period,
        transaction_no: base_txn_no + idx + 1,
        date: txn[:date],
        description: txn[:description] || "",
        tag: txn[:tag] || batch.source_type,
        memo: txn[:memo] || "",
        cardholder: txn[:cardholder] || "",
        status: txn[:status] || "ok",
        journal_entry_lines_attributes: [
          {
            side: "debit",
            account: txn[:debit_account],
            sub_account: txn[:debit_sub_account] || "",
            department: txn[:debit_department] || "",
            partner: txn[:debit_partner] || "",
            tax_category: txn[:debit_tax_category] || "",
            invoice: txn[:debit_invoice] || "",
            amount: txn[:debit_amount]
          },
          {
            side: "credit",
            account: txn[:credit_account],
            sub_account: txn[:credit_sub_account] || "",
            department: txn[:credit_department] || "",
            partner: txn[:credit_partner] || "",
            tax_category: txn[:credit_tax_category] || "",
            invoice: txn[:credit_invoice] || "",
            amount: txn[:credit_amount]
          }
        ]
      )
    end
  end

  def resolve_source_period(batch, data)
    case batch.source_type
    when "receipt"
      build_source_period(data[:receipt_date])
    when "invoice"
      build_source_period(data[:invoice_date])
    else
      data[:statement_period]
    end
  end

  def build_source_period(receipt_date)
    return nil if receipt_date.blank?

    date = Date.parse(receipt_date)
    "#{date.year}年#{date.month}月"
  rescue Date::Error
    nil
  end

  def find_duplicate_receipt(client, transactions)
    return nil if transactions.blank?

    first_txn = transactions.first
    date = first_txn[:date]
    return nil if date.blank?

    amount = first_txn[:debit_amount].to_i
    invoice = first_txn[:debit_invoice].to_s.strip
    partner = first_txn[:debit_partner].to_s.strip

    scope = client.journal_entries
                  .where(source_type: "receipt", date: date)
                  .joins(:journal_entry_lines)
                  .where(journal_entry_lines: { side: "debit", amount: amount })

    if invoice.present?
      scope.where(journal_entry_lines: { invoice: invoice }).first
    elsif partner.present?
      scope.where(journal_entry_lines: { partner: partner }).first
    end
  end

  # AI処理成功後に batch.pdf の blob.filename を命名規約に揃える（ADR 0009-G）。
  # blob 更新失敗は警告ログのみ。仕訳保存とは独立してトランザクション外で呼ぶこと。
  def rename_batch_pdf(batch, data)
    return unless batch.pdf.attached?

    date, vendor, description, ext = extract_pdf_rename_parts(batch, data)
    filename = StatementBatch.build_pdf_filename(date: date, vendor: vendor, description: description, ext: ext)
    batch.pdf.blob.update!(filename: filename)
  rescue => e
    Rails.logger.warn("[PdfRenamer] batch #{batch.id}: #{e.message}")
  end

  def extract_pdf_rename_parts(batch, data)
    ext = batch.pdf.filename.extension_without_delimiter
    first_txn = data[:transactions]&.first || {}

    case batch.source_type
    when "amex"
      date   = parse_statement_period_to_yyyymm(data[:statement_period])
      vendor = "アメックス"
      desc   = "明細"
    when "bank"
      date   = parse_statement_period_to_yyyymm(data[:statement_period])
      vendor = first_txn[:debit_partner].to_s.presence || "銀行"
      desc   = "明細"
    when "invoice"
      date   = data[:invoice_date].to_s
      vendor = data[:vendor_name].to_s
      desc   = first_txn[:description].to_s.presence || "請求書"
    when "receipt"
      date   = data[:receipt_date].to_s
      vendor = data[:vendor_name].to_s.presence || first_txn[:debit_partner].to_s
      desc   = first_txn[:description].to_s.presence || "領収書"
    else
      return ["000000", batch.source_type, "", ext]
    end

    [date, vendor, desc, ext]
  end

  def parse_statement_period_to_yyyymm(period)
    return "000000" if period.blank?

    # "2026年5月" → "202605"
    if period =~ /(\d{4})年(\d{1,2})月/
      format("%04d%02d", $1.to_i, $2.to_i)
    else
      period.gsub(/[^\d]/, "").first(6).presence || "000000"
    end
  end
end
