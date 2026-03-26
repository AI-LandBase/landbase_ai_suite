require "rails_helper"

RSpec.describe CleaningSessionService do
  let(:client) { create(:client, :hotel, code: "test_hotel") }
  let(:manual) { create(:cleaning_manual, :published, client: client) }

  describe ".start" do
    it "セッションを作成すること" do
      session = described_class.start(cleaning_manual: manual, staff_name: "田中", client: client)

      expect(session).to be_persisted
      expect(session.status).to eq("in_progress")
      expect(session.staff_name).to eq("田中")
      expect(session.client).to eq(client)
    end

    it "manual_data からステップレコードを作成すること" do
      session = described_class.start(cleaning_manual: manual, staff_name: "田中", client: client)

      steps = session.cleaning_session_steps
      expect(steps.count).to eq(1)

      step = steps.first
      expect(step.area_name).to eq("寝室")
      expect(step.task).to eq("ベッドメイキング")
      expect(step.status).to eq("pending")
    end

    it "複数エリア・複数ステップのマニュアルでも正しくステップを作成すること" do
      multi_area_manual = create(:cleaning_manual, :published, client: client, manual_data: {
        areas: [
          {
            area_name: "寝室",
            cleaning_steps: [
              { order: 1, task: "ベッドメイキング", description: "desc1", checkpoint: "cp1", estimated_minutes: 5 },
              { order: 2, task: "掃除機がけ", description: "desc2", checkpoint: "cp2", estimated_minutes: 3 }
            ]
          },
          {
            area_name: "バスルーム",
            cleaning_steps: [
              { order: 1, task: "浴槽洗い", description: "desc3", checkpoint: "cp3", estimated_minutes: 10 }
            ]
          }
        ]
      })

      session = described_class.start(cleaning_manual: multi_area_manual, staff_name: "田中", client: client)
      expect(session.cleaning_session_steps.count).to eq(3)
    end
  end

  describe ".current_step_data" do
    it "現在のステップ情報を返すこと" do
      session = described_class.start(cleaning_manual: manual, staff_name: "田中", client: client)
      data = described_class.current_step_data(session)

      expect(data[:task]).to eq("ベッドメイキング")
      expect(data[:area_name]).to eq("寝室")
      expect(data[:description]).to eq("シーツを交換し、枕を配置する")
      expect(data[:checkpoint]).to eq("シーツにしわがないこと")
      expect(data[:total_steps]).to eq(1)
      expect(data[:completed_steps]).to eq(0)
    end

    it "すべて完了の場合は nil を返すこと" do
      session = described_class.start(cleaning_manual: manual, staff_name: "田中", client: client)
      session.cleaning_session_steps.update_all(status: "passed")

      expect(described_class.current_step_data(session)).to be_nil
    end
  end

  describe ".skip_step" do
    it "現在のステップをスキップすること" do
      session = described_class.start(cleaning_manual: manual, staff_name: "田中", client: client)
      step = described_class.skip_step(session)

      expect(step.status).to eq("skipped")
    end

    it "すべて完了の場合は nil を返すこと" do
      session = described_class.start(cleaning_manual: manual, staff_name: "田中", client: client)
      session.cleaning_session_steps.update_all(status: "passed")

      expect(described_class.skip_step(session)).to be_nil
    end
  end

  describe ".suspend / .resume" do
    it "セッションを中断・再開できること" do
      session = described_class.start(cleaning_manual: manual, staff_name: "田中", client: client)

      described_class.suspend(session)
      expect(session.reload.status).to eq("suspended")

      described_class.resume(session)
      expect(session.reload.status).to eq("in_progress")
    end
  end

  describe ".complete" do
    it "セッションを完了にすること" do
      session = described_class.start(cleaning_manual: manual, staff_name: "田中", client: client)
      described_class.complete(session)

      expect(session.reload.status).to eq("completed")
      expect(session.completed_at).to be_present
    end
  end

  describe ".build_report" do
    it "レポートデータを返すこと" do
      session = create(:cleaning_session, cleaning_manual: manual, client: client, started_at: 1.hour.ago, completed_at: Time.current, status: "completed")
      step = create(:cleaning_session_step, :passed, cleaning_session: session, area_name: "寝室", task: "ベッドメイキング")
      create(:cleaning_session_attempt, cleaning_session_step: step, result: "ok", ai_feedback: "良好")

      report = described_class.build_report(session)

      expect(report[:staff_name]).to eq(session.staff_name)
      expect(report[:status]).to eq("completed")
      expect(report[:duration_minutes]).to be_present
      expect(report[:passed_steps]).to eq(1)
      expect(report[:area_results].first[:area_name]).to eq("寝室")
    end
  end
end
