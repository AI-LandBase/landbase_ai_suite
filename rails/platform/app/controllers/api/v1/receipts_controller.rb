module Api
  module V1
    class ReceiptsController < BaseController
      MAX_IMAGE_SIZE = 20.megabytes
      ALLOWED_MIME = %w[image/jpeg image/png image/webp].freeze

      # 1リクエスト = 1画像 = 1領収書バッチ。Web UI は複数画像を1ファイルずつ順次POSTする。
      def process_receipt
        image = params[:image]
        return render_error("画像ファイルをアップロードしてください") if image.blank?

        mime = Marcel::MimeType.for(image.tempfile, name: image.original_filename)
        unless ALLOWED_MIME.include?(mime)
          return render_error("JPEG / PNG / WebP 形式の画像のみ対応しています")
        end

        if image.size > MAX_IMAGE_SIZE
          return render_error("画像ファイルは20MB以下にしてください")
        end

        fingerprint = Digest::SHA256.hexdigest(image.read)
        image.rewind

        unless ActiveModel::Type::Boolean.new.cast(params[:force])
          existing = @current_client.statement_batches
            .where(pdf_fingerprint: fingerprint, status: %w[processing completed duplicate])
            .first
          if existing
            return render json: {
              error: existing.status == "processing" ? "この領収書は現在処理中です" : "この領収書は処理済みです",
              duplicate: true,
              existing_batch_id: existing.id
            }, status: :conflict
          end
        end

        batch = StatementBatch.ingest!(
          client: @current_client,
          source_type: "receipt",
          fingerprint: fingerprint,
          attachable: image
        )

        ReceiptProcessJob.perform_later(batch.id)
        render json: { id: batch.id, status: "processing" }, status: :accepted
      end

      def status
        batch = @current_client.statement_batches.find_by(id: params[:id])
        return render_not_found unless batch

        response = { id: batch.id, status: batch.status }

        case batch.status
        when "completed"
          response[:summary] = batch.summary
          response[:journal_entries_count] = batch.journal_entries.count
        when "duplicate"
          response[:error_message] = batch.error_message
        when "failed"
          response[:error_message] = batch.error_message
        end

        render json: response
      end
    end
  end
end
