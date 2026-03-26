FactoryBot.define do
  factory :cleaning_session_step do
    cleaning_session
    area_name { "寝室" }
    area_index { 0 }
    step_index { 0 }
    task { "ベッドメイキング" }
    status { "pending" }
    attempts_count { 0 }

    trait :passed do
      status { "passed" }
      passed_at { Time.current }
      attempts_count { 1 }
    end

    trait :failed do
      status { "failed" }
      attempts_count { 1 }
    end

    trait :skipped do
      status { "skipped" }
    end
  end
end
