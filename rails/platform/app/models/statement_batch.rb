class StatementBatch < ApplicationRecord
  STATUSES = %w[processing completed failed duplicate].freeze

  VENDOR_MAX_LEN = 30
  DESCRIPTION_MAX_LEN = 30

  # ファイル名規約: YYYYMMDD_支払先_内容.ext（ADR 0009-G）
  # date は "YYYY-MM-DD" / "YYYYMM" / "YYYYMMDD" のいずれでも可（ハイフンを除去して使用）。
  def self.build_pdf_filename(date:, vendor:, description:, ext:)
    sanitize = ->(s) { s.to_s.unicode_normalize(:nfc).gsub(/[\/\\\:\*\?"<>\|　]/, "_").gsub(/\s+/, "_").strip }
    date_str   = date.to_s.gsub("-", "").first(8).presence || "000000"
    vendor_str = sanitize.(vendor).first(VENDOR_MAX_LEN).presence
    desc_str   = sanitize.(description).first(DESCRIPTION_MAX_LEN).presence
    ext_str    = ext.to_s.sub(/\A\./, "").presence || "pdf"
    parts      = [date_str, vendor_str, desc_str].compact
    "#{parts.join("_")}.#{ext_str}"
  end

  # 取り込み（new → attach → save）が失敗したときに raise する。cause_error に元例外を保持する。
  class IngestError < StandardError
    attr_reader :cause_error

    def initialize(message, cause_error:)
      super(message)
      @cause_error = cause_error
    end
  end

  belongs_to :client
  has_many :journal_entries, dependent: :destroy
  has_one_attached :pdf

  validates :source_type, presence: true, inclusion: { in: %w[amex bank invoice receipt] }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :for_client, ->(code) { where(client: Client.where(code: code)) }
  scope :recent, -> { order(created_at: :desc) }

  # 全取り込み経路（receipt-LINE / invoice / amex / bank）共通の取り込みヘルパ。
  #
  # ActiveStorage は実ファイルの upload を after_commit で行う（activestorage model.rb:144）。
  # そのため new → attach → save! でも、upload が ENOSPC/EACCES 等で失敗したときには
  # batch 行が status=processing で「先にコミット済み」になり、ファイル不在の孤児が残る。
  # 再送するとその processing 孤児が dedup にヒットして空ファイルを読み続けるロックになる (issue#302)。
  #
  # ここで save 失敗を捕捉し、コミット済みの孤児を failed に確定する。failed は receipt の
  # dedup(processing/completed/duplicate) にも invoice 系(processing/completed) にも含まれないため、
  # 再送で新しい batch が立ちロックしない。
  #
  # 成功: 永続化済みの batch を返す / 失敗: 孤児を failed 化したうえで IngestError を raise する。
  # attachable は ActiveStorage の attach が受け付ける形（Hash{io:,filename:,content_type:} か UploadedFile）。
  def self.ingest!(client:, source_type:, fingerprint:, attachable:)
    batch = client.statement_batches.new(
      source_type: source_type,
      status: "processing",
      pdf_fingerprint: fingerprint
    )
    batch.pdf.attach(attachable)
    batch.save!
    batch
  rescue => e
    if batch&.persisted?
      batch.update_columns(status: "failed", error_message: "取り込み失敗: #{e.message.presence || e.class}")
      batch.pdf.purge rescue nil
    end
    raise IngestError.new("取り込みに失敗しました", cause_error: e)
  end
end
