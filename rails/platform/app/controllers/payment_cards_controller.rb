class PaymentCardsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_client

  def create
    @payment_card = @client.payment_cards.build(payment_card_params)
    if @payment_card.save
      redirect_to client_path(@client), notice: "カード末尾を登録しました"
    else
      redirect_to client_path(@client), alert: @payment_card.errors.full_messages.join(", ")
    end
  end

  def destroy
    card = @client.payment_cards.find(params[:id])
    card.destroy!
    redirect_to client_path(@client), notice: "カード末尾を削除しました"
  end

  private

  def set_client
    @client = Client.find_by!(code: params[:client_id])
  end

  def payment_card_params
    params.require(:payment_card).permit(:last_four, :card_name)
  end
end
