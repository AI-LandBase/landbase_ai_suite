class CreateJournalEntryRevisions < ActiveRecord::Migration[8.0]
  def change
    create_table :journal_entry_revisions do |t|
      t.references :journal_entry, null: false, foreign_key: true
      # 編集者。User が将来削除されても履歴は会計記録として残すため null 許容 + nullify。
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.jsonb :changes_diff, null: false, default: {}  # { "借方_金額" => [before, after] }
      t.jsonb :snapshot, null: false, default: {}       # 編集後の仕訳全体像（lines 含む）
      t.string :reason                                   # 変更理由（任意）

      t.timestamps
    end

    add_index :journal_entry_revisions, %i[journal_entry_id created_at]
  end
end
