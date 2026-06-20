class Client < ApplicationRecord
  # === 定数 ===
  STATUSES = {
    "active" => "有効",
    "trial" => "トライアル",
    "inactive" => "無効"
  }.freeze

  INDUSTRY_CODES = %w[restaurant hotel tour].freeze
  INDUSTRY_LABELS = {
    "restaurant" => "飲食業",
    "hotel"      => "ホテル",
    "tour"       => "ツアー",
  }.freeze

  INDUSTRY_FEATURES = {
    "hotel"      => %w[cleaning_manuals],
    "restaurant" => %w[],
    "tour"       => %w[],
  }.freeze

  # === 関連 ===
  has_many :journal_entries, dependent: :restrict_with_error
  has_many :account_masters, dependent: :restrict_with_error
  has_many :cleaning_manuals, dependent: :restrict_with_error
  has_many :cleaning_sessions, dependent: :restrict_with_error
  has_many :statement_batches, dependent: :restrict_with_error
  has_many :payment_cards, dependent: :destroy
  has_many :line_followers, dependent: :destroy

  # === バリデーション ===
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES.keys }
  validates :industry, inclusion: { in: INDUSTRY_CODES }, allow_nil: true
  validate :industries_must_be_valid

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

  def industry_codes
    industries.presence || Array(industry)
  end

  def feature_available?(feature)
    key = feature.to_s
    if services.key?(key)
      services[key]
    else
      industry_codes.any? { |code| INDUSTRY_FEATURES.fetch(code, []).include?(key) }
    end
  end

  private

  def industries_must_be_valid
    invalid = industries - INDUSTRY_CODES
    errors.add(:industries, "に無効な値が含まれています: #{invalid.join(', ')}") if invalid.any?
  end
end
