FactoryBot.define do
  factory :journal_entry_revision do
    association :journal_entry
    association :user
    changes_diff { { "摘要" => [ "旧摘要", "新摘要" ] } }
    snapshot { { "摘要" => "新摘要" } }
    reason { nil }
  end
end
