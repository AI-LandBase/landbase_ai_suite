require "rails_helper"

RSpec.describe LineFollower, type: :model do
  describe "バリデーション" do
    it "factoryで有効なレコードを作れること" do
      expect(build(:line_follower)).to be_valid
    end

    it "line_user_idがなければ無効" do
      expect(build(:line_follower, line_user_id: nil)).not_to be_valid
    end

    it "line_user_idが重複すると無効" do
      existing = create(:line_follower)
      duplicate = build(:line_follower, line_user_id: existing.line_user_id)
      expect(duplicate).not_to be_valid
    end

    it "clientがなければ無効" do
      expect(build(:line_follower, client: nil)).not_to be_valid
    end
  end

  describe "関連" do
    it "clientに属する" do
      client = create(:client)
      follower = create(:line_follower, client: client)
      expect(follower.client).to eq(client)
    end

    it "1 Client に対して複数の follower を作れる" do
      client = create(:client)
      create(:line_follower, client: client)
      create(:line_follower, client: client)
      expect(client.line_followers.count).to eq(2)
    end

    it "Client が destroy されたとき関連 follower も削除される" do
      client = create(:client)
      create(:line_follower, client: client)
      expect { client.destroy }.to change(LineFollower, :count).by(-1)
    end
  end
end
