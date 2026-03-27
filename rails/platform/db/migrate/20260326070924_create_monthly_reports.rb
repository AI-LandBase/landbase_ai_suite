class CreateMonthlyReports < ActiveRecord::Migration[8.0]
  def up
    create_table :monthly_reports do |t|
      t.references :client, null: false, foreign_key: true
      t.string :year_month, null: false, comment: "対象年月（例: 2026-03）"
      t.text :content, null: false, comment: "レポート本文（Markdown）"
      t.string :status, null: false, default: "draft", comment: "ステータス（draft/published）"
      t.datetime :generated_at, comment: "AI生成日時"

      t.timestamps
    end

    add_index :monthly_reports, [ :client_id, :year_month ], unique: true
    add_index :monthly_reports, :year_month
  end

  def down
    drop_table :monthly_reports
  end
end
