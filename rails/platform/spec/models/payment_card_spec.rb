require "rails_helper"

RSpec.describe PaymentCard, type: :model do
  let(:client) { create(:client) }

  describe "バリデーション" do
    it "4桁数字のlast_fourは有効" do
      card = build(:payment_card, client: client, last_four: "1234")
      expect(card).to be_valid
    end

    it "last_fourが空の場合は無効" do
      card = build(:payment_card, client: client, last_four: "")
      expect(card).not_to be_valid
      expect(card.errors[:last_four]).to include("を入力してください")
    end

    it "4桁以外（3桁）は無効" do
      card = build(:payment_card, client: client, last_four: "123")
      expect(card).not_to be_valid
      expect(card.errors[:last_four]).to be_present
    end

    it "4桁以外（5桁）は無効" do
      card = build(:payment_card, client: client, last_four: "12345")
      expect(card).not_to be_valid
    end

    it "数字以外は無効" do
      card = build(:payment_card, client: client, last_four: "abcd")
      expect(card).not_to be_valid
    end

    it "同一クライアントで同じlast_fourは重複エラー" do
      create(:payment_card, client: client, last_four: "1234")
      card = build(:payment_card, client: client, last_four: "1234")
      expect(card).not_to be_valid
      expect(card.errors[:last_four]).to include("はすでに登録されています")
    end

    it "別クライアントで同じlast_fourは許可" do
      other_client = create(:client)
      create(:payment_card, client: other_client, last_four: "1234")
      card = build(:payment_card, client: client, last_four: "1234")
      expect(card).to be_valid
    end
  end
end
