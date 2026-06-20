class AddIndustriesToClients < ActiveRecord::Migration[8.0]
  def up
    add_column :clients, :industries, :string, array: true, default: [], null: false,
               comment: "業種（複数選択可）: restaurant / hotel / tour"

    # 既存の単一 industry 値を 1 要素配列に移行
    Client.reset_column_information
    Client.where.not(industry: nil).find_each do |client|
      client.update_columns(industries: [client.industry])
    end
  end

  def down
    remove_column :clients, :industries
  end
end
