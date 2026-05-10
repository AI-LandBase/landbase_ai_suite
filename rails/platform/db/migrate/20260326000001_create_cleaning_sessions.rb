class CreateCleaningSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :cleaning_sessions do |t|
      t.references :cleaning_manual, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :staff_name, null: false
      t.string :status, null: false, default: "in_progress"
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.timestamps
    end

    add_index :cleaning_sessions, [:client_id, :status]
    add_index :cleaning_sessions, [:cleaning_manual_id, :status]
  end
end
