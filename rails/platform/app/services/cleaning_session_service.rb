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
      judge_result = CleaningPhotoJudgeService.new(
        photos: photos,
        task: step.task,
        description: step.description || "",
        checkpoint: step.checkpoint || ""
      ).call

      unless judge_result.success?
        return { success: false, error: judge_result.error }
      end

      # update_all + create! を一括実行して attempts_count と attempts レコードの不整合を防止
      attempt = nil
      ActiveRecord::Base.transaction do
        CleaningSessionStep.where(id: step.id).update_all("attempts_count = attempts_count + 1")
        step.reload

        attempt = step.cleaning_session_attempts.create!(
          attempt_number: step.attempts_count,
          result: judge_result.result,
          ai_feedback: judge_result.feedback,
          judged_at: Time.current
        )
      end

      photos.each { |photo| attempt.photos.attach(photo) }

      if judge_result.result == "ok"
        step.update!(status: "passed", passed_at: Time.current)
      else
        step.update!(status: "failed")
      end

      {
        success: true,
        result: judge_result.result,
        feedback: judge_result.feedback,
        attempt_number: attempt.attempt_number
      }
    end

    def skip_step(session)
      step = session.current_step
      return nil unless step

      step.update!(status: "skipped")
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
