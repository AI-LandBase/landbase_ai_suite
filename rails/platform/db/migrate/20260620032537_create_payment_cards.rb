class CreatePaymentCards < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_cards do |t|
      t.references :client, null: false, foreign_key: true
      t.string :last_four, null: false
      t.string :card_name

      t.timestamps
    end

    add_index :payment_cards, %i[client_id last_four], unique: true
  end
end
