class LineFollower < ApplicationRecord
  belongs_to :client

  validates :line_user_id, presence: true, uniqueness: true
end
