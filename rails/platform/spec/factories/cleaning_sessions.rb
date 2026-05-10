FactoryBot.define do
  factory :cleaning_session do
    cleaning_manual { association :cleaning_manual, :published }
    client { cleaning_manual.client }
    staff_name { "テスト担当者" }
    status { "in_progress" }
    started_at { Time.current }

    trait :completed do
      status { "completed" }
      completed_at { Time.current }
    end

    trait :suspended do
      status { "suspended" }
    end
  end
end
