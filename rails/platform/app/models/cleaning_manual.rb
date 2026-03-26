class CleaningManual < ApplicationRecord
  STATUSES = %w[processing draft published failed].freeze

  belongs_to :client
  has_many :cleaning_sessions, dependent: :restrict_with_error
  has_many_attached :images

  validates :property_name, presence: true
  validates :room_type, presence: true
  validates :manual_data, presence: true, unless: -> { status.in?(%w[processing failed]) }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :for_client, ->(code) { where(client: Client.where(code: code)) }
  scope :published, -> { where(status: "published") }
  scope :recent, -> { order(created_at: :desc) }
end
