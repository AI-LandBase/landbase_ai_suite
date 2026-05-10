class CleaningSession < ApplicationRecord
  STATUSES = %w[in_progress completed suspended].freeze

  belongs_to :cleaning_manual
  belongs_to :client
  has_many :cleaning_session_steps, -> { ordered }, dependent: :destroy

  before_validation :strip_staff_name

  validates :staff_name, presence: true, length: { maximum: 100 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :started_at, presence: true

  scope :for_client, ->(code) { where(client: Client.where(code: code)) }
  scope :active, -> { where(status: "in_progress") }
  scope :recent, -> { order(created_at: :desc) }

  def current_step
    cleaning_session_steps
      .where(status: %w[failed pending])
      .reorder(Arel.sql("CASE status WHEN 'failed' THEN 0 ELSE 1 END"), :area_index, :step_index)
      .first
  end

  def step_counts
    @step_counts ||= cleaning_session_steps.reorder(nil).group(:status).count
  end

  def total_steps_count
    step_counts.values.sum
  end

  def completed_steps_count
    step_counts.fetch("passed", 0) + step_counts.fetch("skipped", 0)
  end

  def reload(*)
    @step_counts = nil
    super
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

  private

  def strip_staff_name
    self.staff_name = staff_name&.strip
  end
end
