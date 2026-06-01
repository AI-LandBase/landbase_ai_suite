class CreateLineFollowers < ActiveRecord::Migration[8.0]
  def change
    create_table :line_followers do |t|
      t.references :client, null: false, foreign_key: true
      t.string :line_user_id, null: false, comment: "LINE user ID"

      t.timestamps
    end

    add_index :line_followers, :line_user_id, unique: true
  end
end
