module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate_request!
      before_action :set_current_client

      # ファイルの upload/attach 失敗（StatementBatch.ingest!）は全経路でここに集約して返す。
      rescue_from StatementBatch::IngestError do |e|
        Rails.logger.error("[#{controller_name}] ingest failed: #{e.cause_error.class}: #{e.cause_error.message}")
        render_error("ファイルの保存に失敗しました。もう一度お試しください。")
      end

      private

      def authenticate_request!
        token = extract_bearer_token
        if token.present?
          api_token = ApiToken.find_by_raw_token(token)

          if api_token.nil? || !api_token.active?
            render json: { error: "Unauthorized" }, status: :unauthorized
            return
          end

          @current_api_token = api_token
          api_token.touch_last_used!
        elsif (user = warden_user)
          return unless valid_session_origin?

          @current_user = user
        else
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def extract_bearer_token
        header = request.headers["Authorization"]
        header&.match(/\ABearer\s+(.+)\z/)&.captures&.first
      end

      def warden_user
        request.env["warden"]&.user
      end

      def valid_session_origin?
        origin = request.headers["Origin"]
        return true if origin.blank?

        allowed = [request.base_url]
        allowed << ENV["APP_ORIGIN"] if ENV["APP_ORIGIN"].present?
        return true if allowed.include?(origin)

        render json: { error: "Unauthorized" }, status: :unauthorized
        false
      end

      def set_current_client
        client_code = params[:client_code]
        return render_error("client_code は必須です", :bad_request) if client_code.blank?

        @current_client = Client.find_by(code: client_code)
        render_error("クライアントが見つかりません", :not_found) unless @current_client
      end

      def render_error(message, status = :unprocessable_entity)
        render json: { error: message }, status: status
      end

      def render_not_found
        render json: { error: "リソースが見つかりません" }, status: :not_found
      end
    end
  end
end
