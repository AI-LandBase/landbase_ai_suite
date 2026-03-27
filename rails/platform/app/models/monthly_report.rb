class MonthlyReport < ApplicationRecord
  # === 定数 ===
  STATUSES = {
    "draft" => "下書き",
    "published" => "公開"
  }.freeze

  # === 関連 ===
  belongs_to :client

  # === バリデーション ===
  validates :year_month, presence: true,
    format: { with: /\A\d{4}-\d{2}\z/, message: "はYYYY-MM形式で入力してください" },
    uniqueness: { scope: :client_id, message: "のレポートは既に存在します" }
  validates :content, presence: true
  validates :status, inclusion: { in: STATUSES.keys }

  # === スコープ ===
  scope :for_client, ->(code) { where(client: Client.where(code: code)) }
  scope :recent, -> { order(year_month: :desc) }
  scope :published, -> { where(status: "published") }

  def status_label
    STATUSES[status]
  end

  def display_year_month
    if year_month =~ /\A(\d{4})-(\d{2})\z/
      "#{$1}年#{$2.to_i}月"
    else
      year_month
    end
  end
end
