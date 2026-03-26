class CleaningSession < ApplicationRecord
  STATUSES = %w[in_progress completed suspended].freeze

  belongs_to :cleaning_manual
  belongs_to :client
  has_many :cleaning_session_steps, -> { ordered }, dependent: :destroy

  validates :staff_name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :started_at, presence: true

  scope :for_client, ->(code) { where(client: Client.where(code: code)) }
  scope :active, -> { where(status: "in_progress") }
  scope :recent, -> { order(created_at: :desc) }

  def current_step
    cleaning_session_steps.ordered.find_by(status: "pending") ||
      cleaning_session_steps.ordered.find_by(status: "failed")
  end

  def total_steps_count
    cleaning_session_steps.size
  end

  def completed_steps_count
    cleaning_session_steps.where(status: %w[passed skipped]).count
  end

  def in_progress?
    status == "in_progress"
  end

  def completed?
    status == "completed"
  end

  def suspended?
    status == "suspended"
  end
end
