class MonthlyReportGeneratorService
  NON_RETRYABLE_REASONS = %i[config_error no_data].freeze

  Result = Data.define(:success, :data, :error, :reason) do
    alias_method :success?, :success
    def retryable? = !success && !NON_RETRYABLE_REASONS.include?(reason)
  end

  INDUSTRY_PROMPTS = {
    "hotel" => <<~PROMPT,
      ### 業種固有の分析観点（宿泊業）
      以下の観点を重点的に分析してください：
      - **稼働率分析**: 売上と客室数から推定される稼働率の推移
      - **客単価分析**: 宿泊売上÷推定宿泊数による客単価トレンド
      - **清掃コスト比率**: 清掃関連費用（外注費・消耗品費等）の売上比率
      - **設備メンテナンスサイクル**: 修繕費・消耗品費の発生パターン
      - **季節変動分析**: 前月・前年同月との比較による季節トレンド
      - **光熱費分析**: 水道光熱費の推移と季節要因
      - **OTA手数料分析**: 支払手数料の内訳と比率
    PROMPT
    "restaurant" => <<~PROMPT,
      ### 業種固有の分析観点（飲食業）
      以下の観点を重点的に分析してください：
      - **原価率分析**: 仕入高÷売上高による原価率の推移
      - **売上推移**: 日次・週次の売上パターン分析
      - **仕入先別分析**: 主要仕入先ごとの支出傾向
      - **食材ロス傾向**: 廃棄損・雑損失の推移
      - **人件費率**: 給与・外注費の売上比率
      - **光熱費分析**: 水道光熱費の推移（特にガス・電気）
      - **販促効果**: 広告宣伝費と売上の相関
    PROMPT
    "tour" => <<~PROMPT
      ### 業種固有の分析観点（アクティビティ・ツアー）
      以下の観点を重点的に分析してください：
      - **参加者数推移**: 売上から推定される参加者数のトレンド
      - **単価分析**: 売上÷推定参加者数による単価推移
      - **天候連動分析**: 季節・天候による売上変動パターン
      - **安全関連費用**: 保険料・安全設備費の推移
      - **車両・機材費**: 車両費・リース料・修繕費の管理状況
      - **季節プログラム提案**: データに基づく季節別プログラム最適化の提言
      - **集客チャネル分析**: 広告宣伝費・支払手数料から推定される集客構造
    PROMPT
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT
    あなたは沖縄県北部の観光事業に精通した経営コンサルタントです。
    クライアントの仕訳データを分析し、月次オペレーション分析レポートを作成してください。

    ### レポートの基本構成（Markdown形式で出力）

    1. **エグゼクティブサマリー** — 3〜5行で当月の経営状態を要約
    2. **収支概要** — 売上・費用・利益の概要をテーブル形式で表示
    3. **勘定科目別分析** — 主要な勘定科目ごとの金額・前月比・特記事項
    4. **業種固有の分析** — 業種に応じた専門的な分析（後述のプロンプトに従う）
    5. **リスク・注意事項** — 異常値、要確認事項、経営上の懸念点
    6. **改善提案** — データに基づく具体的なアクションアイテム（3〜5件）
    7. **次月の見通し** — 季節要因やトレンドに基づく予測

    ### 出力ルール
    - **Markdown形式**で出力する（JSON不要）
    - テーブル・箇条書き・見出しを活用して読みやすくする
    - 金額は3桁区切りカンマ付きで表示（例: 1,234,567円）
    - 根拠のない推測は避け、データに基づく分析を心がける
    - 仕訳データが少ない場合は、分析可能な範囲で対応し、データ不足の旨を明記する
    - レポートタイトル（H1見出し）は不要。本文のみを出力する
  PROMPT

  def initialize(client:, year_month:)
    @client = client
    @year_month = year_month
  end

  def call
    unless ENV["ANTHROPIC_API_KEY"].present?
      return Result.new(success: false, data: nil, error: "ANTHROPIC_API_KEY が設定されていません", reason: :config_error)
    end

    journal_data = build_journal_data
    if journal_data[:entries_count] == 0
      return Result.new(success: false, data: nil, error: "#{@year_month} の仕訳データがありません", reason: :no_data)
    end

    prompt = build_user_prompt(journal_data)
    response = call_api(prompt)

    text_block = response.content.find { |c| c.respond_to?(:type) && c.type.to_s == "text" }
    content = text_block&.respond_to?(:text) ? text_block.text : text_block.to_s

    if content.blank?
      return Result.new(success: false, data: nil, error: "AIからの応答が空でした", reason: :api_error)
    end

    report = save_report(content)
    Result.new(success: true, data: report, error: nil, reason: nil)
  rescue Anthropic::Errors::APIError => e
    Result.new(success: false, data: nil, error: "Anthropic API エラー: #{e.message}", reason: :api_error)
  rescue StandardError => e
    Result.new(success: false, data: nil, error: "予期しないエラー: #{e.message}", reason: :unexpected_error)
  end

  private

  def build_journal_data
    date_range = parse_year_month_range
    entries = JournalEntry.where(client: @client)
                          .in_period(date_range.first, date_range.last)
                          .includes(:journal_entry_lines)

    debit_summary = {}
    credit_summary = {}

    entries.each do |entry|
      entry.debit_lines.each do |line|
        debit_summary[line.account] ||= 0
        debit_summary[line.account] += line.amount.to_i
      end
      entry.credit_lines.each do |line|
        credit_summary[line.account] ||= 0
        credit_summary[line.account] += line.amount.to_i
      end
    end

    {
      entries_count: entries.size,
      total_debit: debit_summary.values.sum,
      total_credit: credit_summary.values.sum,
      debit_by_account: debit_summary.sort_by { |_, v| -v }.to_h,
      credit_by_account: credit_summary.sort_by { |_, v| -v }.to_h,
      entries_sample: entries.limit(500).map { |e|
        {
          date: e.date,
          description: e.description,
          source_type: e.source_type,
          debits: e.debit_lines.map { |l| { account: l.account, sub_account: l.sub_account, amount: l.amount.to_i } },
          credits: e.credit_lines.map { |l| { account: l.account, sub_account: l.sub_account, amount: l.amount.to_i } }
        }
      }
    }
  end

  def build_user_prompt(journal_data)
    industry_prompt = INDUSTRY_PROMPTS.fetch(@client.industry.to_s, <<~FALLBACK)
      ### 業種固有の分析観点（汎用）
      以下の観点で分析してください：
      - **収支バランス分析**: 売上と費用の構成比
      - **固定費・変動費分析**: 費用の固変分解
      - **キャッシュフロー傾向**: 入出金のタイミングとパターン
      - **主要取引先分析**: 支出上位の取引先と傾向
    FALLBACK

    <<~PROMPT
      以下のクライアントの #{@year_month} 月次オペレーション分析レポートを作成してください。

      ### クライアント情報
      - 名称: #{@client.name}
      - 業種: #{@client.industry || "未設定"}
      - コード: #{@client.code}

      #{industry_prompt}

      ### 仕訳データサマリー
      - 仕訳件数: #{journal_data[:entries_count]}件
      - 借方合計: #{journal_data[:total_debit].to_s(:delimited)}円
      - 貸方合計: #{journal_data[:total_credit].to_s(:delimited)}円

      ### 借方（費用・資産）科目別集計
      #{format_account_summary(journal_data[:debit_by_account])}

      ### 貸方（収益・負債）科目別集計
      #{format_account_summary(journal_data[:credit_by_account])}

      ### 仕訳明細データ（最大500件）
      #{journal_data[:entries_sample].map { |e| format_entry(e) }.join("\n")}
    PROMPT
  end

  def format_account_summary(account_hash)
    return "（データなし）" if account_hash.empty?

    lines = account_hash.map do |account, amount|
      "| #{account} | #{amount.to_s(:delimited)}円 |"
    end

    "| 勘定科目 | 金額 |\n|---|---|\n#{lines.join("\n")}"
  end

  def format_entry(entry)
    debits = entry[:debits].map { |d| "#{d[:account]}#{d[:sub_account].present? ? "/#{d[:sub_account]}" : ""} #{d[:amount].to_s(:delimited)}円" }.join(", ")
    credits = entry[:credits].map { |c| "#{c[:account]}#{c[:sub_account].present? ? "/#{c[:sub_account]}" : ""} #{c[:amount].to_s(:delimited)}円" }.join(", ")
    "- #{entry[:date]} | #{entry[:description]} | 借方: #{debits} | 貸方: #{credits}"
  end

  def parse_year_month_range
    year, month = @year_month.split("-").map(&:to_i)
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month
    start_date..end_date
  end

  def save_report(content)
    report = MonthlyReport.find_or_initialize_by(client: @client, year_month: @year_month)
    report.update!(
      content: content,
      status: "draft",
      generated_at: Time.current
    )
    report
  end

  def call_api(prompt)
    api_client.messages.create(
      model: ENV.fetch("ANTHROPIC_MODEL", "claude-sonnet-4-6"),
      max_tokens: 8192,
      system: SYSTEM_PROMPT,
      messages: [ { role: "user", content: prompt } ]
    )
  end

  def api_client
    @api_client ||= Anthropic::Client.new(timeout: 120.0)
  end
end
