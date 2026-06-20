class PaymentCard < ApplicationRecord
  belongs_to :client

  validates :last_four, presence: true,
                        format: { with: /\A\d{4}\z/, message: "は4桁の数字で入力してください" },
                        uniqueness: { scope: :client_id, message: "はすでに登録されています" }
  validates :card_name, length: { maximum: 50 }

  scope :for_client, ->(client) { where(client: client) }
end
