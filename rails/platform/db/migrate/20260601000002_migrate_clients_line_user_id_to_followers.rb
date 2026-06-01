class MigrateClientsLineUserIdToFollowers < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      INSERT INTO line_followers (client_id, line_user_id, created_at, updated_at)
      SELECT id, line_user_id, NOW(), NOW()
      FROM clients
      WHERE line_user_id IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      UPDATE clients c
      SET line_user_id = lf.line_user_id
      FROM line_followers lf
      WHERE lf.client_id = c.id
    SQL
  end
end
