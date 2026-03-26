class CleaningManualsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  before_action :set_client
  before_action :require_feature!

  def index
    @manuals = if @client
                 CleaningManual.for_client(@client_code).recent
               else
                 CleaningManual.none
               end
  end

  def show
    @manual = CleaningManual.for_client(@client_code).find(params[:id])
  end

  def new
  end

  private

  def set_client
    @client_code = params[:client_code].presence
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
    redirect_to cleaning_manuals_path(client_code: @client_code), alert: "マニュアルが見つかりません"
  end
end
