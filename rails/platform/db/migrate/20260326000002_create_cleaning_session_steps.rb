class CreateCleaningSessionSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :cleaning_session_steps do |t|
      t.references :cleaning_session, null: false, foreign_key: true
      t.string :area_name, null: false
      t.integer :area_index, null: false
      t.integer :step_index, null: false
      t.string :task, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts_count, null: false, default: 0
      t.datetime :passed_at
      t.timestamps
    end

    add_index :cleaning_session_steps,
              [:cleaning_session_id, :area_index, :step_index],
              unique: true,
              name: "idx_session_steps_unique"
  end
end
