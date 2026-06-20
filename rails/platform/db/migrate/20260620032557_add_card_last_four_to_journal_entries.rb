class AddCardLastFourToJournalEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :journal_entries, :card_last_four, :string
  end
end
