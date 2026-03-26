FactoryBot.define do
  factory :client do
    sequence(:code) { |n| "client_#{n}" }
    sequence(:name) { |n| "テストクライアント#{n}" }
    industry { "restaurant" }
    services { {} }
    status { "active" }

    trait :hotel do
      industry { "accommodation" }
    end

    trait :inactive do
      status { "inactive" }
    end

    trait :trial do
      status { "trial" }
    end

    trait :with_line do
      sequence(:line_user_id) { |n| "U#{n.to_s.rjust(32, '0')}" }
    end
  end
end
