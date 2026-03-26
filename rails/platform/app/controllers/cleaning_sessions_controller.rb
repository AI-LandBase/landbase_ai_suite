class CleaningSessionsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  before_action :set_client
  before_action :require_feature!

  def new
    @manual = CleaningManual.for_client(@client_code).published.find(params[:cleaning_manual_id])
    @manual_data = @manual.manual_data.deep_symbolize_keys
  end

  def show
    @session = CleaningSession.for_client(@client_code).find(params[:id])
    @manual = @session.cleaning_manual
  end

  def report
    @session = CleaningSession.for_client(@client_code).find(params[:id])
    @manual = @session.cleaning_manual
    @report = CleaningSessionService.build_report(@session)
  end

  private

  def set_client
    @client_code = params[:client_code] || ""
    @client = Client.find_by(code: @client_code)
  end

  def require_feature!
    return if @client&.feature_available?(:cleaning_manuals)

    if @client
      redirect_to client_path(@client), alert: "この機能はご利用いただけません"
    else
      redirect_to clients_path, alert: "クライアントを選択してください"
    end
  end

  def record_not_found
    redirect_to cleaning_manuals_path(client_code: @client_code), alert: "セッションが見つかりません"
  end
end
