module Api
  module V1
    class InvoicesController < BaseController
      include PdfStatementProcessable

      def process_statement
        ingest_pdf_statement(source_type: "invoice", job: InvoiceProcessJob, noun: "請求書")
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
