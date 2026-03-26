require "rails_helper"

RSpec.describe CleaningSessionStep, type: :model do
  describe "バリデーション" do
    it "有効なファクトリであること" do
      step = build(:cleaning_session_step)
      expect(step).to be_valid
    end

    it "area_name が必須であること" do
      step = build(:cleaning_session_step, area_name: nil)
      expect(step).not_to be_valid
    end

    it "task が必須であること" do
      step = build(:cleaning_session_step, task: nil)
      expect(step).not_to be_valid
    end

    it "status が不正な値の場合エラーになること" do
      step = build(:cleaning_session_step, status: "invalid")
      expect(step).not_to be_valid
    end
  end

  describe "スコープ" do
    describe ".ordered" do
      it "area_index, step_index の昇順で返すこと" do
        session = create(:cleaning_session)
        step_b = create(:cleaning_session_step, cleaning_session: session, area_index: 1, step_index: 0)
        step_a = create(:cleaning_session_step, cleaning_session: session, area_index: 0, step_index: 1)
        step_first = create(:cleaning_session_step, cleaning_session: session, area_index: 0, step_index: 0)

        result = CleaningSessionStep.ordered
        expect(result).to eq([step_first, step_a, step_b])
      end
    end
  end
end
