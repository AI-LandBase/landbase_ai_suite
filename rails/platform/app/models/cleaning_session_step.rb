class CleaningSessionStep < ApplicationRecord
  STATUSES = %w[pending passed failed skipped].freeze

  belongs_to :cleaning_session
  has_many :cleaning_session_attempts, -> { order(:attempt_number) }, dependent: :destroy

  validates :area_name, presence: true
  validates :task, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :ordered, -> { order(area_index: :asc, step_index: :asc) }
end
