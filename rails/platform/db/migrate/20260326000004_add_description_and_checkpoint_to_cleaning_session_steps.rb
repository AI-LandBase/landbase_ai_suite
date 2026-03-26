class AddDescriptionAndCheckpointToCleaningSessionSteps < ActiveRecord::Migration[8.0]
  def change
    add_column :cleaning_session_steps, :description, :text
    add_column :cleaning_session_steps, :checkpoint, :text
    add_column :cleaning_session_steps, :estimated_minutes, :integer
  end
end
