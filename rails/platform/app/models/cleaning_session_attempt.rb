class CleaningSessionAttempt < ApplicationRecord
  RESULTS = %w[ok ng].freeze

  belongs_to :cleaning_session_step
  has_many_attached :photos

  validates :attempt_number, presence: true
  validates :result, presence: true, inclusion: { in: RESULTS }
  validates :judged_at, presence: true
end
