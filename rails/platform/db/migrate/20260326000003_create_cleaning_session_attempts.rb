class CreateCleaningSessionAttempts < ActiveRecord::Migration[8.0]
  def change
    create_table :cleaning_session_attempts do |t|
      t.references :cleaning_session_step, null: false, foreign_key: true
      t.integer :attempt_number, null: false
      t.string :result, null: false
      t.text :ai_feedback
      t.datetime :judged_at, null: false
      t.timestamps
    end

    add_index :cleaning_session_attempts,
              [:cleaning_session_step_id, :attempt_number],
              unique: true,
              name: "idx_session_attempts_unique"
  end
end
