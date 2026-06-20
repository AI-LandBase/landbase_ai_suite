class JournalEntriesController < ApplicationController
  include JournalEntryExportable

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  before_action :require_client_code
  before_action :set_client

  def index
    @source_type = params[:source_type] || ""
    @csv_export_status = params[:csv_export_status] || ""
    scope = JournalEntry.for_client(@client_code).includes(:journal_entry_lines)
    scope = scope.by_source(@source_type) if @source_type.present?
    scope = apply_csv_export_filter(scope, @csv_export_status)
    @entries = scope.order(date: :desc, transaction_no: :asc).page(params[:page]).per(25)
    @registered_last_fours = PaymentCard.where(client: @client).pluck(:last_four).to_set
  end

  def show
    @entry = JournalEntry.for_client(@client_code)
                         .includes(:journal_entry_lines, statement_batch: { pdf_attachment: :blob })
                         .find(params[:id])
    @registered_last_fours = PaymentCard.where(client: @client).pluck(:last_four).to_set
  end

  def edit
    @entry = JournalEntry.for_client(@client_code).includes(:journal_entry_lines).find(params[:id])
  end

  def update
    @entry = JournalEntry.for_client(@client_code).includes(:journal_entry_lines).find(params[:id])

    if @entry.update(entry_params)
      redirect_to journal_entry_path(@entry, client_code: @client_code), notice: "仕訳を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry = JournalEntry.for_client(@client_code).find(params[:id])
    @entry.destroy!
    redirect_to journal_entries_path(client_code: @client_code), notice: "仕訳を削除しました"
  end

  def export
    entries = JournalEntry.for_client(@client_code)
    entries = entries.by_source(params[:source_type]) if params[:source_type].present?
    entries = entries.where(statement_batch_id: params[:statement_batch_id]) if params[:statement_batch_id].present?
    entries = apply_csv_export_filter(entries, params[:csv_export_status])
    if params[:date_from].present? && params[:date_to].present?
      begin
        entries = entries.in_period(Date.parse(params[:date_from]), Date.parse(params[:date_to]))
      rescue Date::Error
        redirect_to journal_entries_path(client_code: @client_code), alert: "日付の形式が不正です" and return
      end
    end

    entries = entries.order(date: :asc, transaction_no: :asc)

    send_journal_csv(entries, format_type: params[:format_type])
  end

  private

  def apply_csv_export_filter(scope, status)
    case status
    when "unexported" then scope.csv_unexported
    when "exported"   then scope.csv_exported
    else scope
    end
  end

  def require_client_code
    @client_code = params[:client_code]
    redirect_to clients_path, alert: "クライアントを選択してください" if @client_code.blank?
  end

  def set_client
    @client = Client.find_by!(code: @client_code)
  end

  def entry_params
    params.require(:journal_entry).permit(
      :description, :tag, :memo, :cardholder, :status,
      journal_entry_lines_attributes: [
        :id, :side, :account, :sub_account, :department,
        :partner, :tax_category, :invoice, :amount, :_destroy
      ]
    )
  end

  def record_not_found
    redirect_to clients_path, alert: "仕訳が見つかりません"
  end
end
