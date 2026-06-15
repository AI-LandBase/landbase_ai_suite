class StatementBatchesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  def show
    @batch = StatementBatch.find(params[:id])
    @client = @batch.client || raise(ActiveRecord::RecordNotFound)
    @sidebar_client = @client
  end

  def destroy
    client_code = params[:client_code]
    @batch = StatementBatch.for_client(client_code).find(params[:id])
    je_count = @batch.journal_entries.count
    @batch.destroy!
    redirect_to journal_entries_path(client_code: client_code),
                notice: "処理バッチを削除しました（仕訳 #{je_count} 件もあわせて削除）"
  end

  private

  def record_not_found
    redirect_to clients_path, alert: "処理バッチが見つかりません"
  end
end
