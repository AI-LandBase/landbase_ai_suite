module Api
  module V1
    class CleaningSessionsController < BaseController
      ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
      MAX_IMAGE_SIZE = 10.megabytes
      MAX_IMAGE_COUNT = 5

      before_action :require_feature!
      before_action :set_session, except: [:create]

      # POST /api/v1/cleaning_manuals/:cleaning_manual_id/cleaning_sessions
      def create
        manual = @current_client.cleaning_manuals.published.find_by(id: params[:cleaning_manual_id])
        return render_not_found unless manual

        staff_name = params[:staff_name]
        return render_error("staff_name は必須です") if staff_name.blank?

        session = CleaningSessionService.start(
          cleaning_manual: manual,
          staff_name: staff_name,
          client: @current_client
        )

        render json: session_json(session), status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(", "))
      end

      # GET /api/v1/cleaning_sessions/:id
      def show
        render json: session_json(@session)
      end

      # GET /api/v1/cleaning_sessions/:id/current_step
      def current_step
        step_data = CleaningSessionService.current_step_data(@session)

        if step_data
          render json: step_data
        else
          render json: { message: "すべてのステップが完了しています" }
        end
      end

      # POST /api/v1/cleaning_sessions/:id/judge
      def judge
        return render_error("セッションは進行中ではありません") unless @session.in_progress?

        step = @session.current_step
        return render_error("判定するステップがありません") unless step

        photos = params[:photos] || []
        return render_error("写真を1枚以上送信してください") if photos.empty?
        return render_error("写真は#{MAX_IMAGE_COUNT}枚以下にしてください") if photos.size > MAX_IMAGE_COUNT

        invalid = photos.reject { |img| Marcel::MimeType.for(img.tempfile, name: img.original_filename).in?(ALLOWED_CONTENT_TYPES) }
        return render_error("対応していない画像形式です。JPEG, PNG, WebP のみ対応しています。") if invalid.any?

        oversized = photos.select { |img| img.size > MAX_IMAGE_SIZE }
        return render_error("画像は1枚あたり10MB以下にしてください。") if oversized.any?

        result = CleaningSessionService.judge(
          session: @session,
          step: step,
          photos: photos
        )

        if result[:success]
          auto_complete_if_done

          render json: {
            result: result[:result],
            feedback: result[:feedback],
            attempt_number: result[:attempt_number],
            next_step: CleaningSessionService.current_step_data(@session.reload),
            session_status: @session.status,
            completed_steps: @session.completed_steps_count,
            total_steps: @session.total_steps_count
          }
        else
          render_error(result[:error])
        end
      end

      # PATCH /api/v1/cleaning_sessions/:id/skip
      def skip
        return render_error("セッションは進行中ではありません") unless @session.in_progress?

        step = CleaningSessionService.skip_step(@session)
        return render_error("スキップするステップがありません") unless step

        auto_complete_if_done

        render json: {
          skipped_step: { task: step.task, area_name: step.area_name },
          next_step: CleaningSessionService.current_step_data(@session.reload),
          session_status: @session.status,
          completed_steps: @session.completed_steps_count,
          total_steps: @session.total_steps_count
        }
      end

      # PATCH /api/v1/cleaning_sessions/:id/suspend
      def suspend
        return render_error("セッションは進行中ではありません") unless @session.in_progress?

        CleaningSessionService.suspend(@session)
        render json: { status: @session.status }
      end

      # PATCH /api/v1/cleaning_sessions/:id/resume
      def resume
        return render_error("セッションは中断中ではありません") unless @session.suspended?

        CleaningSessionService.resume(@session)
        render json: session_json(@session.reload)
      end

      # GET /api/v1/cleaning_sessions/:id/report
      def report
        render json: CleaningSessionService.build_report(@session)
      end

      private

      def set_session
        @session = @current_client.cleaning_sessions.find_by(id: params[:id])
        render_not_found unless @session
      end

      def require_feature!
        return if @current_client&.feature_available?(:cleaning_manuals)

        render json: { error: "この機能はご利用いただけません" }, status: :forbidden
      end

      def session_json(session)
        {
          id: session.id,
          cleaning_manual_id: session.cleaning_manual_id,
          staff_name: session.staff_name,
          status: session.status,
          started_at: session.started_at,
          completed_at: session.completed_at,
          total_steps: session.total_steps_count,
          completed_steps: session.completed_steps_count
        }
      end

      def auto_complete_if_done
        return unless @session.in_progress?

        if @session.current_step.nil?
          CleaningSessionService.complete(@session)
        end
      end
    end
  end
end
