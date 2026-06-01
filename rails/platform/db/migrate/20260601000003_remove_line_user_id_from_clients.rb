class RemoveLineUserIdFromClients < ActiveRecord::Migration[8.0]
  def change
    remove_index :clients, name: "index_clients_on_line_user_id"
    remove_column :clients, :line_user_id, :string, comment: "LINE user ID（Webhook識別用）"
  end
end
