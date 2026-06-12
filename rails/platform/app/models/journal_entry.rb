require "csv"

class JournalEntry < ApplicationRecord
  # === 関連 ===
  belongs_to :client
  belongs_to :statement_batch, optional: true
  has_many :journal_entry_lines, -> { order(:id) }, dependent: :destroy
  accepts_nested_attributes_for :journal_entry_lines, allow_destroy: true

  # === バリデーション ===
  validates :date, presence: true
  validates :source_type, inclusion: { in: %w[amex bank invoice receipt] }
  validates :status, inclusion: { in: %w[ok review_required] }
  validates :transaction_no, uniqueness: { scope: %i[client_id source_type source_period] }, allow_nil: true
  validate :amounts_must_balance

  # === スコープ ===
  scope :for_client, ->(code) { where(client: Client.where(code: code)) }
  scope :by_source, ->(type) { where(source_type: type) }
  scope :review_required, -> { where(status: "review_required") }
  scope :in_period, ->(from, to) { where(date: from..to) }
  scope :csv_unexported, -> { where(exported_at: nil) }
  scope :csv_exported, -> { where.not(exported_at: nil) }

  # === 便利メソッド ===
  def debit_lines
    journal_entry_lines.select { |l| l.side == "debit" }
  end

  def credit_lines
    journal_entry_lines.select { |l| l.side == "credit" }
  end

  def debit_amount
    debit_lines.sum(&:amount)
  end

  def credit_amount
    credit_lines.sum(&:amount)
  end

  def simple_entry?
    journal_entry_lines.size == 2
  end

  # === CSVエクスポート ===
  CSV_HEADERS = %w[
    取引No 取引日 借方勘定科目 借方補助科目 借方部門 借方取引先 借方税区分
    借方インボイス 借方金額(円) 貸方勘定科目 貸方補助科目 貸方部門
    貸方取引先 貸方税区分 貸方インボイス 貸方金額(円) 摘要 タグ メモ カード利用者 ステータス
  ].freeze

  def self.to_csv
    CSV.generate(headers: true) do |csv|
      csv << CSV_HEADERS

      all.includes(:journal_entry_lines).each do |entry|
        debits = entry.debit_lines
        credits = entry.credit_lines
        next if debits.empty? || credits.empty?

        max_lines = [ debits.size, credits.size ].max
        max_lines.times do |i|
          debit = debits[i]
          credit = credits[i]

          csv << [
            entry.transaction_no,
            entry.date,
            debit&.account,
            debit&.sub_account,
            debit&.department,
            debit&.partner,
            debit&.tax_category,
            debit&.invoice,
            debit&.amount,
            credit&.account,
            credit&.sub_account,
            credit&.department,
            credit&.partner,
            credit&.tax_category,
            credit&.invoice,
            credit&.amount,
            i == 0 ? entry.description : "",
            i == 0 ? entry.tag : "",
            i == 0 ? entry.memo : "",
            i == 0 ? entry.cardholder : "",
            i == 0 ? entry.status : ""
          ]
        end
      end
    end
  end

  private

  def amounts_must_balance
    return if journal_entry_lines.empty?

    debit_total = journal_entry_lines.select { |l| l.side == "debit" }.sum { |l| l.amount.to_i }
    credit_total = journal_entry_lines.select { |l| l.side == "credit" }.sum { |l| l.amount.to_i }

    if debit_total != credit_total
      errors.add(:base, "借方合計と貸方合計が一致しません（借方: #{debit_total}, 貸方: #{credit_total}）")
    end
  end
end
