FactoryBot.define do
  factory :line_follower do
    association :client
    sequence(:line_user_id) { |n| "U#{n.to_s.rjust(32, '0')}" }
  end
end
