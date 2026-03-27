namespace :reports do
  desc "全activeクライアントの前月分月次レポートを生成"
  task generate_monthly: :environment do
    year_month = 1.month.ago.strftime("%Y-%m")
    clients = Client.active

    puts "=== 月次レポート生成 (#{year_month}) ==="
    puts "対象クライアント数: #{clients.count}"

    success_count = 0
    error_count = 0

    clients.find_each do |client|
      print "  #{client.name} (#{client.code})... "

      service = MonthlyReportGeneratorService.new(client: client, year_month: year_month)
      result = service.call

      if result.success?
        puts "OK"
        success_count += 1
      else
        puts "NG: #{result.error}"
        error_count += 1
      end
    rescue StandardError => e
      puts "ERROR: #{e.message}"
      error_count += 1
    end

    puts "=== 完了: 成功 #{success_count}件, 失敗 #{error_count}件 ==="
  end
end
