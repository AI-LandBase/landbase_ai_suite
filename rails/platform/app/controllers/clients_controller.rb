class ClientsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  def index
    @clients = Client.visible.search(params[:query]).order(:code)
  end

  def show
    @client = Client.find_by!(code: params[:id])
  end

  def new
    @client = Client.new(status: "active")
  end

  def create
    @client = Client.new(create_params)
    if @client.save
      redirect_to client_path(@client), notice: "クライアントを作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @client = Client.find_by!(code: params[:id])
  end

  def update
    @client = Client.find_by!(code: params[:id])
    if @client.update(update_params)
      redirect_to client_path(@client), notice: "クライアントを更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client = Client.find_by!(code: params[:id])
    @client.update!(status: "inactive")
    redirect_to clients_path, notice: "クライアントを無効化しました"
  end

  private

  def create_params
    params.require(:client).permit(:code, :name, :industry, :status, industries: [])
  end

  def update_params
    params.require(:client).permit(:name, :industry, :status, industries: [])
  end

  def record_not_found
    redirect_to clients_path, alert: "クライアントが見つかりません"
  end
end
