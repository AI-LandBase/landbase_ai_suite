FactoryBot.define do
  factory :cleaning_session_attempt do
    cleaning_session_step
    attempt_number { 1 }
    result { "ok" }
    ai_feedback { "清掃状態は良好です。" }
    judged_at { Time.current }

    trait :ng do
      result { "ng" }
      ai_feedback { "ベッドシーツにしわが残っています。" }
    end
  end
end
