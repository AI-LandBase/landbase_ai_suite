class AddExportedAtToJournalEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :journal_entries, :exported_at, :datetime, comment: "CSV出力日時（NULL=未出力）"
    add_index :journal_entries, :exported_at,
              name: "idx_journal_entries_csv_unexported",
              where: "exported_at IS NULL"
  end
end
