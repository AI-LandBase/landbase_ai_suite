class ReceiptsController < ApplicationController
  def new
    @client = Client.find_by(code: params[:client_code])
  end
end
