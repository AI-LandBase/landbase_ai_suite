FactoryBot.define do
  factory :client do
    sequence(:code) { |n| "client_#{n}" }
    sequence(:name) { |n| "テストクライアント#{n}" }
    industry { "restaurant" }
    services { {} }
    status { "active" }

    trait :hotel do
      industry { "hotel" }
    end

    trait :inactive do
      status { "inactive" }
    end

    trait :trial do
      status { "trial" }
    end

    trait :with_line_follower do
      after(:create) do |client|
        create(:line_follower, client: client)
      end
    end
  end
end
