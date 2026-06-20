FactoryBot.define do
  factory :payment_card do
    association :client
    sequence(:last_four) { |n| format("%04d", n % 9999 + 1) }
    card_name { "法人AMEX" }
  end
end
