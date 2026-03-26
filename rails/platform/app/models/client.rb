class Client < ApplicationRecord
  # === 定数 ===
  STATUSES = {
    "active" => "有効",
    "trial" => "トライアル",
    "inactive" => "無効"
  }.freeze

  INDUSTRIES = {
    "accommodation" => "宿泊業",
    "restaurant" => "飲食業",
    "activity" => "アクティビティ",
    "retail" => "小売業",
    "rental_car" => "レンタカー",
    "beauty" => "美容・リラクゼーション",
    "other" => "その他"
  }.freeze

  INDUSTRY_FEATURES = {
    "accommodation" => %w[cleaning_manuals],
  }.freeze

  # === 関連 ===
  has_many :journal_entries, dependent: :restrict_with_error
  has_many :account_masters, dependent: :restrict_with_error
  has_many :cleaning_manuals, dependent: :restrict_with_error
  has_many :statement_batches, dependent: :restrict_with_error

  # === バリデーション ===
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES.keys }
  validates :industry, inclusion: { in: INDUSTRIES.keys }, allow_nil: true
  validates :line_user_id, uniqueness: true, allow_nil: true

  # === スコープ ===
  scope :active, -> { where(status: "active") }
  scope :visible, -> { where(status: %w[active trial]) }
  scope :search, ->(query) {
    if query.present?
      sanitized = "%#{sanitize_sql_like(query)}%"
      where("code ILIKE :q OR name ILIKE :q", q: sanitized)
    else
      all
    end
  }

  def to_param
    code
  end

  def status_label
    STATUSES[status]
  end

  def industry_label
    INDUSTRIES[industry]
  end

  def feature_available?(feature)
    key = feature.to_s
    if services.key?(key)
      services[key]
    else
      INDUSTRY_FEATURES.fetch(industry.to_s, []).include?(key)
    end
  end
end
