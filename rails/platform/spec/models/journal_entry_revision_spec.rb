require "rails_helper"

RSpec.describe JournalEntryRevision, type: :model do
  let(:client) { create(:client) }
  let(:user) { create(:user) }

  describe ".diff_snapshots" do
    it "変化したキーのみ [before, after] で返すこと" do
      before = { "摘要" => "A", "メモ" => "X", "借方_金額" => "100" }
      after  = { "摘要" => "B", "メモ" => "X", "借方_金額" => "200" }

      diff = described_class.diff_snapshots(before, after)

      expect(diff).to eq({ "摘要" => [ "A", "B" ], "借方_金額" => [ "100", "200" ] })
    end

    it "新規追加・削除されたキーも検出すること" do
      before = { "a" => "1" }
      after  = { "a" => "1", "b" => "2" }

      expect(described_class.diff_snapshots(before, after)).to eq({ "b" => [ nil, "2" ] })
    end

    it "差分が無ければ空ハッシュを返すこと" do
      snap = { "摘要" => "A" }
      expect(described_class.diff_snapshots(snap, snap)).to eq({})
    end
  end

  describe ".record!" do
    let(:entry) do
      create(:journal_entry, client: client, description: "元の摘要",
             debit_account: "旅費交通費", debit_amount: 1000, credit_amount: 1000)
    end

    it "差分がある場合にリビジョンを作成すること" do
      before = entry.revision_snapshot
      entry.update!(description: "修正後の摘要")

      expect {
        described_class.record!(entry: entry, before: before, user: user, reason: "摘要を訂正")
      }.to change(described_class, :count).by(1)

      rev = described_class.last
      expect(rev.journal_entry).to eq(entry)
      expect(rev.user).to eq(user)
      expect(rev.reason).to eq("摘要を訂正")
      expect(rev.changes_diff["摘要"]).to eq([ "元の摘要", "修正後の摘要" ])
      expect(rev.snapshot["摘要"]).to eq("修正後の摘要")
    end

    it "差分が無い場合はリビジョンを作成しないこと" do
      before = entry.revision_snapshot

      expect {
        described_class.record!(entry: entry, before: before, user: user, reason: "理由のみ")
      }.not_to change(described_class, :count)
    end

    it "reason が空文字の場合は nil で保存すること" do
      before = entry.revision_snapshot
      entry.update!(memo: "メモ追加")

      described_class.record!(entry: entry, before: before, user: user, reason: "")
      expect(described_class.last.reason).to be_nil
    end
  end

  describe "#editor_label" do
    it "user がいればメールアドレスを返すこと" do
      rev = build(:journal_entry_revision, user: user)
      expect(rev.editor_label).to eq(user.email)
    end

    it "user が nil なら不明ラベルを返すこと" do
      rev = build(:journal_entry_revision, user: nil)
      expect(rev.editor_label).to eq("（不明な編集者）")
    end
  end
end
