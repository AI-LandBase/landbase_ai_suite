class JournalEntryRevision < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :user, optional: true

  validates :changes_diff, presence: true

  scope :recent_first, -> { order(created_at: :desc) }

  # 2 つのスナップショット（フラット hash）を比較し、変化したキーだけ
  # { key => [before, after] } 形式で返す。
  def self.diff_snapshots(before, after)
    (before.keys | after.keys).each_with_object({}) do |key, diff|
      old_value = before[key]
      new_value = after[key]
      diff[key] = [ old_value, new_value ] if old_value != new_value
    end
  end

  # 編集前スナップショット before を受け取り、entry の現在値と差分を取って
  # リビジョンを記録する。差分が無ければ何もしない（理由のみの保存は不要）。
  def self.record!(entry:, before:, user: nil, reason: nil)
    after = entry.revision_snapshot
    diff = diff_snapshots(before, after)
    return nil if diff.empty?

    create!(
      journal_entry: entry,
      user: user,
      changes_diff: diff,
      snapshot: after,
      reason: reason.presence
    )
  end

  def editor_label
    user&.email || "（不明な編集者）"
  end
end
