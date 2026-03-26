# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if Rails.env.development?
  User.find_or_create_by!(email: "admin@example.com") do |user|
    user.password = "password"
    user.password_confirmation = "password"
  end
  puts "管理者ユーザーを作成しました: admin@example.com / password"

  ApiToken.where(name: "development").delete_all
  _token_record, raw_token = ApiToken.generate!(name: "development")
  puts "APIトークンを作成しました: #{raw_token}"
  puts "使用方法: curl -H 'Authorization: Bearer #{raw_token}' http://localhost:3000/api/v1/..."

  # デモクライアント
  client = Client.find_or_create_by!(code: "demo") do |c|
    c.name = "デモ会社"
    c.industry = "accommodation"
  end
  client.update!(industry: "accommodation") if client.industry.blank?
  puts "デモクライアントを作成しました: #{client.name} (#{client.code}) [#{client.industry}]"

  # サンプル仕訳（単一仕訳）
  unless JournalEntry.exists?(client: client, source_type: "amex", transaction_no: 1, source_period: "2026-03")
    JournalEntry.create!(
      client: client,
      source_type: "amex",
      source_period: "2026-03",
      transaction_no: 1,
      date: Date.new(2026, 3, 5),
      description: "事務用品購入（Amazon）",
      tag: "amex",
      cardholder: "山田太郎",
      status: "ok",
      journal_entry_lines_attributes: [
        { side: "debit", account: "消耗品費", partner: "Amazon", tax_category: "課税仕入10%", amount: 3280 },
        { side: "credit", account: "未払金", sub_account: "Amex", amount: 3280 }
      ]
    )
    puts "サンプル仕訳（単一）を作成しました"
  end

  # サンプル仕訳（複合仕訳）
  unless JournalEntry.exists?(client: client, source_type: "bank", transaction_no: 2, source_period: "2026-03")
    JournalEntry.create!(
      client: client,
      source_type: "bank",
      source_period: "2026-03",
      transaction_no: 2,
      date: Date.new(2026, 3, 1),
      description: "3月分給与支払い",
      tag: "bank",
      status: "review_required",
      journal_entry_lines_attributes: [
        { side: "debit", account: "給与手当", amount: 300_000 },
        { side: "credit", account: "普通預金", sub_account: "琉球銀行", amount: 250_000 },
        { side: "credit", account: "所得税預り金", amount: 30_000 },
        { side: "credit", account: "社会保険料預り金", amount: 20_000 }
      ]
    )
    puts "サンプル仕訳（複合）を作成しました"
  end
end
