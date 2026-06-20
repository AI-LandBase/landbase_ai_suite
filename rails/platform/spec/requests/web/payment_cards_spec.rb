require "rails_helper"

RSpec.describe "Web::PaymentCards", type: :request do
  let(:user) { create(:user) }
  let(:client) { create(:client) }

  describe "POST /clients/:client_id/payment_cards" do
    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        post client_payment_cards_path(client), params: { payment_card: { last_four: "1234" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "有効な末尾4桁でカードを登録しクライアント詳細にリダイレクトすること" do
        expect {
          post client_payment_cards_path(client), params: { payment_card: { last_four: "1234", card_name: "法人AMEX" } }
        }.to change(PaymentCard, :count).by(1)

        expect(response).to redirect_to(client_path(client))
        expect(PaymentCard.last.last_four).to eq("1234")
        expect(PaymentCard.last.card_name).to eq("法人AMEX")
      end

      it "無効な末尾（4桁以外）はリダイレクトしてalertを返すこと" do
        expect {
          post client_payment_cards_path(client), params: { payment_card: { last_four: "12" } }
        }.not_to change(PaymentCard, :count)

        expect(response).to redirect_to(client_path(client))
      end

      it "重複登録はリダイレクトしてalertを返すこと" do
        create(:payment_card, client: client, last_four: "1234")

        expect {
          post client_payment_cards_path(client), params: { payment_card: { last_four: "1234" } }
        }.not_to change(PaymentCard, :count)

        expect(response).to redirect_to(client_path(client))
      end
    end
  end

  describe "DELETE /clients/:client_id/payment_cards/:id" do
    let!(:card) { create(:payment_card, client: client, last_four: "5678") }

    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        delete client_payment_card_path(client, card)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "カードを削除しクライアント詳細にリダイレクトすること" do
        expect {
          delete client_payment_card_path(client, card)
        }.to change(PaymentCard, :count).by(-1)

        expect(response).to redirect_to(client_path(client))
      end

      it "他クライアントのカードは削除できないこと" do
        other_client = create(:client)
        other_card = create(:payment_card, client: other_client, last_four: "9999")

        delete client_payment_card_path(client, other_card)

        expect(other_card.reload).to be_persisted
      end
    end
  end
end
