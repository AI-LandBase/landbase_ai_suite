require "rails_helper"

RSpec.describe CleaningSession, type: :model do
  describe "バリデーション" do
    it "有効なファクトリであること" do
      session = build(:cleaning_session)
      expect(session).to be_valid
    end

    it "staff_name が必須であること" do
      session = build(:cleaning_session, staff_name: nil)
      expect(session).not_to be_valid
      expect(session.errors[:staff_name]).to be_present
    end

    it "status が必須であること" do
      session = build(:cleaning_session, status: nil)
      expect(session).not_to be_valid
    end

    it "status が不正な値の場合エラーになること" do
      session = build(:cleaning_session, status: "invalid")
      expect(session).not_to be_valid
      expect(session.errors[:status]).to be_present
    end

    it "started_at が必須であること" do
      session = build(:cleaning_session, started_at: nil)
      expect(session).not_to be_valid
    end
  end

  describe "スコープ" do
    describe ".for_client" do
      it "指定した client_code のセッションのみ返すこと" do
        client_a = create(:client, :hotel, code: "client_a")
        client_b = create(:client, :hotel, code: "client_b")
        manual_a = create(:cleaning_manual, :published, client: client_a)
        manual_b = create(:cleaning_manual, :published, client: client_b)
        session_a = create(:cleaning_session, cleaning_manual: manual_a, client: client_a)
        _session_b = create(:cleaning_session, cleaning_manual: manual_b, client: client_b)

        result = CleaningSession.for_client("client_a")
        expect(result).to contain_exactly(session_a)
      end
    end

    describe ".active" do
      it "進行中のセッションのみ返すこと" do
        active = create(:cleaning_session)
        _completed = create(:cleaning_session, :completed)

        result = CleaningSession.active
        expect(result).to contain_exactly(active)
      end
    end
  end

  describe "#current_step" do
    it "最初のpendingステップを返すこと" do
      session = create(:cleaning_session)
      _passed = create(:cleaning_session_step, :passed, cleaning_session: session, area_index: 0, step_index: 0)
      pending_step = create(:cleaning_session_step, cleaning_session: session, area_index: 0, step_index: 1)

      expect(session.current_step).to eq(pending_step)
    end

    it "failedステップがある場合はそれを返すこと" do
      session = create(:cleaning_session)
      failed_step = create(:cleaning_session_step, :failed, cleaning_session: session, area_index: 0, step_index: 0)

      expect(session.current_step).to eq(failed_step)
    end

    it "すべて完了の場合はnilを返すこと" do
      session = create(:cleaning_session)
      create(:cleaning_session_step, :passed, cleaning_session: session)

      expect(session.current_step).to be_nil
    end
  end

  describe "#completed_steps_count" do
    it "passed と skipped の合計を返すこと" do
      session = create(:cleaning_session)
      create(:cleaning_session_step, :passed, cleaning_session: session, area_index: 0, step_index: 0)
      create(:cleaning_session_step, :skipped, cleaning_session: session, area_index: 0, step_index: 1)
      create(:cleaning_session_step, cleaning_session: session, area_index: 0, step_index: 2)

      expect(session.completed_steps_count).to eq(2)
    end
  end
end
