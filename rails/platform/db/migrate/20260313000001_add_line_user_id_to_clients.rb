class AddLineUserIdToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :line_user_id, :string
    add_index :clients, :line_user_id, unique: true
  end
end
