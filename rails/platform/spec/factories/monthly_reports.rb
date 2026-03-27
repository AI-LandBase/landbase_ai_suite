FactoryBot.define do
  factory :monthly_report do
    client
    sequence(:year_month) { |n| "2026-#{(n % 12 + 1).to_s.rjust(2, '0')}" }
    content { "## エグゼクティブサマリー\n\nテストレポートの内容です。" }
    status { "draft" }
    generated_at { Time.current }

    trait :published do
      status { "published" }
    end
  end
end
