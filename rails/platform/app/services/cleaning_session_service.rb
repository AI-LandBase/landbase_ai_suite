class CleaningSessionService
  class << self
    def start(cleaning_manual:, staff_name:, client:)
      manual_data = cleaning_manual.manual_data.deep_symbolize_keys
      areas = manual_data[:areas] || []

      session = CleaningSession.new(
        cleaning_manual: cleaning_manual,
        client: client,
        staff_name: staff_name,
        status: "in_progress",
        started_at: Time.current
      )

      areas.each_with_index do |area, area_idx|
        steps = area[:cleaning_steps] || []

        steps.each_with_index do |step, step_idx|
          session.cleaning_session_steps.build(
            area_name: area[:area_name],
            area_index: area_idx,
            step_index: step_idx,
            task: step[:task],
            description: step[:description],
            checkpoint: step[:checkpoint],
            estimated_minutes: step[:estimated_minutes],
            status: "pending"
          )
        end
      end

      session.save!
      session
    end

    def current_step_data(session)
      step = session.current_step
      return nil unless step

      {
        step_id: step.id,
        area_name: step.area_name,
        area_index: step.area_index,
        step_index: step.step_index,
        task: step.task,
        description: step.description,
        checkpoint: step.checkpoint,
        estimated_minutes: step.estimated_minutes,
        status: step.status,
        attempts_count: step.attempts_count,
        total_steps: session.total_steps_count,
        completed_steps: session.completed_steps_count
      }
    end

    def judge(session:, step:, photos:)
      # 1. ロック取得 + 状態チェック（短いトランザクション）
      locked_step = ActiveRecord::Base.transaction do
        s = session.cleaning_session_steps.lock.find(step.id)
        s.status.in?(%w[pending failed]) ? s : nil
      end
      return { success: false, error: "このステップは既に処理済みです" } unless locked_step

      # 2. AI判定（トランザクション外 — ロック保持しない）
      judge_result = CleaningPhotoJudgeService.new(
        photos: photos,
        task: locked_step.task,
        description: locked_step.description || "",
        checkpoint: locked_step.checkpoint || ""
      ).call

      unless judge_result.success?
        return { success: false, error: judge_result.error }
      end

      # 3. DB更新（短いトランザクション — ロック再取得 + 状態再検証 + 一括更新）
      attempt = nil
      ActiveRecord::Base.transaction do
        locked_step = session.cleaning_session_steps.lock.find(locked_step.id)
        unless locked_step.status.in?(%w[pending failed])
          return { success: false, error: "このステップは既に処理済みです" }
        end

        CleaningSessionStep.where(id: locked_step.id).update_all("attempts_count = attempts_count + 1")
        locked_step.reload

        attempt = locked_step.cleaning_session_attempts.create!(
          attempt_number: locked_step.attempts_count,
          result: judge_result.result,
          ai_feedback: judge_result.feedback,
          judged_at: Time.current
        )

        if judge_result.result == "ok"
          locked_step.update!(status: "passed", passed_at: Time.current)
        else
          locked_step.update!(status: "failed")
        end
      end

      photos.each { |photo| attempt.photos.attach(photo) }

      {
        success: true,
        result: judge_result.result,
        feedback: judge_result.feedback,
        attempt_number: attempt.attempt_number
      }
    end

    def skip_step(session)
      step = ActiveRecord::Base.transaction do
        s = session.current_step
        return nil unless s

        locked = session.cleaning_session_steps.lock.find(s.id)
        return nil unless locked.status.in?(%w[pending failed])

        locked.update!(status: "skipped")
        locked
      end
      step
    end

    def suspend(session)
      session.update!(status: "suspended")
    end

    def resume(session)
      session.update!(status: "in_progress")
    end

    def complete(session)
      session.update!(status: "completed", completed_at: Time.current)
    end

    def build_report(session)
      steps = session.cleaning_session_steps.includes(
        cleaning_session_attempts: { photos_attachments: :blob }
      ).ordered

      area_results = steps.group_by(&:area_name).map do |area_name, area_steps|
        {
          area_name: area_name,
          steps: area_steps.map do |step|
            {
              task: step.task,
              status: step.status,
              attempts_count: step.attempts_count,
              attempts: step.cleaning_session_attempts.map do |attempt|
                {
                  attempt_number: attempt.attempt_number,
                  result: attempt.result,
                  feedback: attempt.ai_feedback,
                  judged_at: attempt.judged_at
                }
              end
            }
          end
        }
      end

      duration_minutes = if session.started_at && session.completed_at
                           ((session.completed_at - session.started_at) / 60.0).round(1)
      end

      {
        session_id: session.id,
        staff_name: session.staff_name,
        status: session.status,
        started_at: session.started_at,
        completed_at: session.completed_at,
        duration_minutes: duration_minutes,
        total_steps: session.total_steps_count,
        passed_steps: steps.count { |s| s.status == "passed" },
        skipped_steps: steps.count { |s| s.status == "skipped" },
        failed_steps: steps.count { |s| s.status == "failed" },
        total_attempts: steps.sum(&:attempts_count),
        area_results: area_results
      }
    end
  end
end
