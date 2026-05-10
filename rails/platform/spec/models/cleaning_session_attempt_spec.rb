require "rails_helper"

RSpec.describe CleaningSessionAttempt, type: :model do
  describe "バリデーション" do
    it "有効なファクトリであること" do
      attempt = build(:cleaning_session_attempt)
      expect(attempt).to be_valid
    end

    it "attempt_number が必須であること" do
      attempt = build(:cleaning_session_attempt, attempt_number: nil)
      expect(attempt).not_to be_valid
    end

    it "result が必須であること" do
      attempt = build(:cleaning_session_attempt, result: nil)
      expect(attempt).not_to be_valid
    end

    it "result が不正な値の場合エラーになること" do
      attempt = build(:cleaning_session_attempt, result: "invalid")
      expect(attempt).not_to be_valid
    end

    it "judged_at が必須であること" do
      attempt = build(:cleaning_session_attempt, judged_at: nil)
      expect(attempt).not_to be_valid
    end
  end
end
