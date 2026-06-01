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
end
