module Api
  module V1
    class JournalEntriesController < BaseController
      include JournalEntryExportable

      def index
        entries = @current_client.journal_entries.includes(:journal_entry_lines)

        entries = entries.by_source(params[:source_type]) if params[:source_type].present?
        entries = entries.review_required if params[:review_required] == "true"
        case params[:csv_export_status]
        when "unexported" then entries = entries.csv_unexported
        when "exported"   then entries = entries.csv_exported
        end
        if params[:date_from].present? && params[:date_to].present?
          begin
            entries = entries.in_period(Date.parse(params[:date_from]), Date.parse(params[:date_to]))
          rescue Date::Error
            return render_error("日付の形式が不正です（YYYY-MM-DD）")
          end
        end
        if params[:statement_batch_id].present?
          entries = entries.where(statement_batch_id: params[:statement_batch_id])
        end

        entries = entries.order(date: :desc, transaction_no: :asc)
                        .page(params[:page]).per(params[:per_page] || 25)

        render json: {
          entries: entries.map { |e| entry_json(e) },
          meta: {
            current_page: entries.current_page,
            total_pages: entries.total_pages,
            total_count: entries.total_count
          }
        }
      end

      def show
        entry = @current_client.journal_entries.includes(:journal_entry_lines).find_by(id: params[:id])
        return render_not_found unless entry

        render json: entry_json(entry)
      end

      def update
        entry = @current_client.journal_entries.includes(:journal_entry_lines).find_by(id: params[:id])
        return render_not_found unless entry

        if entry.update(entry_params)
          render json: entry_json(entry)
        else
          render_error(entry.errors.full_messages.join(", "))
        end
      end

      def export
        entries = @current_client.journal_entries.includes(:journal_entry_lines)

        entries = entries.by_source(params[:source_type]) if params[:source_type].present?
        case params[:csv_export_status]
        when "unexported" then entries = entries.csv_unexported
        when "exported"   then entries = entries.csv_exported
        end
        if params[:statement_batch_id].present?
          entries = entries.where(statement_batch_id: params[:statement_batch_id])
        end
        if params[:date_from].present? && params[:date_to].present?
          begin
            entries = entries.in_period(Date.parse(params[:date_from]), Date.parse(params[:date_to]))
          rescue Date::Error
            return render_error("日付の形式が不正です（YYYY-MM-DD）")
          end
        end

        entries = entries.order(date: :asc, transaction_no: :asc)

        send_journal_csv(entries, format_type: params[:format_type])
      end

      private

      def entry_params
        params.permit(
          :description, :tag, :memo, :cardholder, :status,
          journal_entry_lines_attributes: [
            :id, :side, :account, :sub_account, :department,
            :partner, :tax_category, :invoice, :amount, :_destroy
          ]
        )
      end

      def entry_json(entry)
        debit = entry.debit_lines.first
        credit = entry.credit_lines.first

        {
          id: entry.id,
          transaction_no: entry.transaction_no,
          date: entry.date,
          debit_account: debit&.account,
          debit_sub_account: debit&.sub_account,
          debit_department: debit&.department,
          debit_partner: debit&.partner,
          debit_tax_category: debit&.tax_category,
          debit_invoice: debit&.invoice,
          debit_amount: debit&.amount,
          credit_account: credit&.account,
          credit_sub_account: credit&.sub_account,
          credit_department: credit&.department,
          credit_partner: credit&.partner,
          credit_tax_category: credit&.tax_category,
          credit_invoice: credit&.invoice,
          credit_amount: credit&.amount,
          description: entry.description,
          tag: entry.tag,
          memo: entry.memo,
          cardholder: entry.cardholder,
          status: entry.status,
          source_type: entry.source_type,
          source_period: entry.source_period,
          statement_batch_id: entry.statement_batch_id,
          lines: entry.journal_entry_lines.map { |l| line_json(l) },
          created_at: entry.created_at,
          updated_at: entry.updated_at
        }
      end

      def line_json(line)
        {
          id: line.id,
          side: line.side,
          account: line.account,
          sub_account: line.sub_account,
          department: line.department,
          partner: line.partner,
          tax_category: line.tax_category,
          invoice: line.invoice,
          amount: line.amount
        }
      end
    end
  end
end
