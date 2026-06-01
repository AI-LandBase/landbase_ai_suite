class StatementBatch < ApplicationRecord
  STATUSES = %w[processing completed failed duplicate].freeze

  belongs_to :client
  has_many :journal_entries, dependent: :nullify
  has_one_attached :pdf

  validates :source_type, presence: true, inclusion: { in: %w[amex bank invoice receipt] }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :for_client, ->(code) { where(client: Client.where(code: code)) }
  scope :recent, -> { order(created_at: :desc) }
end
