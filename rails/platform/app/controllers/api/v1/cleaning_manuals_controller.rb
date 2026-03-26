module Api
  module V1
    class CleaningManualsController < BaseController
      ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/avif].freeze
      MAX_IMAGE_SIZE = 10.megabytes
      MAX_IMAGE_COUNT = 50

      before_action :require_feature!

      def index
        manuals = @current_client.cleaning_manuals.recent
        render json: manuals.map { |m| manual_summary(m) }
      end

      def show
        manual = @current_client.cleaning_manuals.find_by(id: params[:id])
        return render_not_found unless manual

        render json: manual_detail(manual)
      end

      def generate
        images = params[:images] || []
        return render_error("画像を1枚以上アップロードしてください") if images.empty?
        return render_error("画像は#{MAX_IMAGE_COUNT}枚以下にしてください") if images.size > MAX_IMAGE_COUNT

        invalid = images.reject { |img| Marcel::MimeType.for(img.tempfile, name: img.original_filename).in?(ALLOWED_CONTENT_TYPES) }
        if invalid.any?
          return render_error("対応していない画像形式が含まれています。JPEG, PNG, WebP, AVIF のみ対応しています。")
        end

        oversized = images.select { |img| img.size > MAX_IMAGE_SIZE }
        if oversized.any?
          return render_error("画像は1枚あたり10MB以下にしてください。")
        end

        property_name = params[:property_name]
        room_type = params[:room_type]
        return render_error("property_name は必須です") if property_name.blank?
        return render_error("room_type は必須です") if room_type.blank?

        labels = params[:labels] || []

        manual = @current_client.cleaning_manuals.new(
          property_name: property_name,
          room_type: room_type,
          manual_data: {},
          status: "processing"
        )

        images.each { |img| manual.images.attach(img) }

        if manual.save
          CleaningManualGenerateJob.perform_later(manual.id, labels: labels.map(&:to_s))
          render json: { id: manual.id, status: "processing" }, status: :accepted
        else
          render_error(manual.errors.full_messages.join(", "))
        end
      end

      def status
        manual = @current_client.cleaning_manuals.find_by(id: params[:id])
        return render_not_found unless manual

        response = { id: manual.id, status: manual.status }

        case manual.status
        when "draft", "published"
          response.merge!(manual_detail(manual))
        when "failed"
          response[:error_message] = manual.error_message
        end

        render json: response
      end

      private

      def manual_summary(manual)
        {
          id: manual.id,
          property_name: manual.property_name,
          room_type: manual.room_type,
          status: manual.status,
          created_at: manual.created_at,
          updated_at: manual.updated_at
        }
      end

      def manual_detail(manual)
        {
          id: manual.id,
          client_code: manual.client.code,
          property_name: manual.property_name,
          room_type: manual.room_type,
          status: manual.status,
          manual_data: manual.manual_data,
          images: manual.images.map { |img| rails_blob_url(img) },
          created_at: manual.created_at,
          updated_at: manual.updated_at
        }
      end

      def rails_blob_url(blob)
        Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: true)
      end

      def require_feature!
        return if @current_client&.feature_available?(:cleaning_manuals)

        render json: { error: "この機能はご利用いただけません" }, status: :forbidden
      end
    end
  end
end
