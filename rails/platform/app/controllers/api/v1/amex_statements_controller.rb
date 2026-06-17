module Api
  module V1
    class AmexStatementsController < BaseController
      MAX_PDF_SIZE = 20.megabytes

      def process_statement
        pdf = params[:pdf]
        return render_error("PDFファイルをアップロードしてください") if pdf.blank?

        unless Marcel::MimeType.for(pdf.tempfile, name: pdf.original_filename) == "application/pdf"
          return render_error("PDF形式のファイルのみ対応しています")
        end

        if pdf.size > MAX_PDF_SIZE
          return render_error("PDFファイルは20MB以下にしてください")
        end

        fingerprint = Digest::SHA256.hexdigest(pdf.read)
        pdf.rewind

        unless ActiveModel::Type::Boolean.new.cast(params[:force])
          existing = @current_client.statement_batches
            .where(pdf_fingerprint: fingerprint, status: %w[processing completed])
            .first
          if existing
            return render json: {
              error: existing.status == "processing" ? "この明細は現在処理中です" : "この明細は処理済みです",
              duplicate: true,
              existing_batch_id: existing.id
            }, status: :conflict
          end
        end

        batch = StatementBatch.ingest!(
          client: @current_client,
          source_type: "amex",
          fingerprint: fingerprint,
          attachable: pdf
        )

        AmexStatementProcessJob.perform_later(batch.id)
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
        when "failed"
          response[:error_message] = batch.error_message
        end

        render json: response
      end
    end
  end
end
