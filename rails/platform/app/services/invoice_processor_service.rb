require "combine_pdf"

class InvoiceProcessorService
  NON_RETRYABLE_REASONS = %i[config_error].freeze

  Result = Data.define(:success, :data, :error, :reason) do
    alias_method :success?, :success
    def retryable? = !success && !NON_RETRYABLE_REASONS.include?(reason)
  end

  INITIAL_BATCH_SIZE = 20
  MIN_BATCH_SIZE = 5

  SYSTEM_PROMPT = <<~PROMPT
    あなたは日本の経理・簿記の専門家です。以下のルールに厳密に従い、請求書 PDF から抽出したデータを仕訳台帳データに変換してください。

    ### 前提知識

    - **複式簿記**: すべての取引は借方・貸方の両方に同額を記録する
    - **請求書の仕訳**:
      - 借方: 費用科目（請求内容から推定）
      - 貸方: 「買掛金」（仕入の場合）または「未払金」（それ以外の費用）
    - **請求書は非定型**: 発行元ごとにフォーマットが異なるため、PDFの内容を柔軟に読み取る必要がある
    - **通常1件の仕訳**: 請求書は1通につき1件の仕訳に合算する（明細行が複数あっても合計金額で1仕訳）

    ### 請求書データ抽出ルール

    請求書 PDF から以下の情報を読み取る。発行元ごとにレイアウトが異なるため、ラベルや位置を柔軟に解釈する。

    | 抽出項目 | 抽出方法 | 備考 |
    |---|---|---|
    | 請求日 | 「請求日」「発行日」「日付」等のラベル付近 | YYYY-MM-DD に変換 |
    | 請求元（取引先名） | 社名・屋号・ロゴ付近 | 正式名称を使用 |
    | 請求番号 | 「請求書番号」「No.」「番号」等 | そのまま記録 |
    | 請求金額（税込合計） | 「合計」「ご請求金額」「お支払金額」等 | 税込金額を使用 |
    | 消費税額 | 「消費税」「税額」等 | 明記されている場合のみ |
    | 明細行 | 品名・数量・単価・金額のテーブル | 勘定科目推定の参考にする |
    | 支払期限 | 「支払期限」「お振込期限」「支払期日」等 | memo に記録 |
    | インボイス番号 | T+13桁の数字（例: T1234567890123） | 登録番号・適格請求書番号 |
    | 振込先 | 「振込先」「お支払先」等の口座情報 | memo に記載 |

    #### インボイス番号の検出

    - PDF 内に `T` + 13桁の数字（例: `T1234567890123`）が記載されているか検索する
    - 「登録番号」「適格請求書発行事業者登録番号」「インボイス番号」等のラベルが付いていることが多い
    - 検出できた場合: `has_invoice_number: true`、`debit_invoice` にT番号を記録
    - 検出できなかった場合: `has_invoice_number: false`、`debit_invoice` は空文字

    ### 勘定科目推定ルール

    請求書の取引先名・明細内容から、以下のルールで借方勘定科目を推定する。

    #### キーワードベースの推定（高精度）

    | 取引先・内容キーワード | 借方勘定科目 | 備考 |
    |---|---|---|
    | システム開発, ソフトウェア開発, プログラミング | 外注費 | |
    | 広告, マーケティング, プロモーション | 広告宣伝費 | |
    | コンサルティング, 顧問, アドバイザリー | 支払手数料 | |
    | 商品仕入, 材料, 原材料 | 仕入高 | |
    | Web, クラウド, SaaS, サーバー, ホスティング | 通信費 | |
    | 事務用品, 文具, オフィス用品 | 消耗品費 | |
    | デザイン, クリエイティブ, 制作 | 外注費 | |
    | 清掃, メンテナンス, 保守 | 外注費 or 修繕費 | 定期清掃は外注費、設備修繕は修繕費 |
    | 弁護士, 司法書士, 行政書士, 税理士, 会計士 | 支払手数料 | 士業報酬 |
    | 研修, セミナー, トレーニング | 研修費 | |

    #### AI 推論（低精度）

    上記ルールでマッチしない場合は、取引先名・明細内容から最も適切な勘定科目を推論する。ただし、推論に自信がない場合は `status` を `"review_required"` に設定し、`memo` に推論理由を記載する。

    ### 消費税・インボイス対応ルール

    #### インボイス番号あり（T+13桁検出）

    | 条件 | 借方税区分 | debit_invoice |
    |------|-----------|---------------|
    | 標準税率（10%） | 課税仕入10%（インボイス） | T+13桁番号 |
    | 軽減税率（8%） | 課税仕入8%（軽減・インボイス） | T+13桁番号 |

    #### インボイス番号なし

    | 条件 | 借方税区分 | debit_invoice |
    |------|-----------|---------------|
    | 標準税率（10%） | 課税仕入10%（非インボイス） | 空文字 |
    | 軽減税率（8%） | 課税仕入8%（軽減・非インボイス） | 空文字 |

    #### 軽減税率の判定

    - 食品・飲料（酒類を除く）に関する請求は軽減税率8%を適用
    - それ以外はデフォルトで標準税率10%を適用

    #### その他注意事項

    - 請求書に税率の内訳が明記されている場合は、その記載に従う
    - 非課税取引（保険料、印紙代等の実費）は `debit_tax_category` を `"非課税仕入"` とする
    - 判断が困難な場合は標準税率10%（インボイス有無に応じた区分）を適用し、`memo` に「税率要確認」と記載する

    ### 貸方勘定科目判定ルール

    借方勘定科目に基づいて、貸方勘定科目を判定する。

    | 借方勘定科目 | 貸方勘定科目 | 備考 |
    |-------------|-------------|------|
    | 仕入高 | 買掛金 | 商品・材料の仕入に対する債務 |
    | 上記以外（外注費、通信費、消耗品費等） | 未払金 | 仕入以外の費用に対する債務 |

    ### 処理上の注意事項

    1. **金額の扱い**: PDF に記載された税込合計金額を使用する。借方金額と貸方金額は必ず一致させる
    2. **日付の扱い**: 請求日を YYYY-MM-DD 形式に変換して `date` に設定する
    3. **複数明細行の合算**: 請求書に複数の明細行がある場合、合計金額で1件の仕訳に合算する。個別明細は `description` や `memo` に含める
    4. **取引先名**: PDF に記載された正式名称をそのまま使用する（「株式会社」「合同会社」等を含む）
    5. **インボイス番号の検証**: T+13桁のパターンに一致するか確認する。類似するが形式が異なる番号は `memo` に「インボイス番号形式不一致：要確認」と記載する
    6. **貸方取引先**: 請求元名を `credit_partner` にも記録する（債務の相手先を明確にするため）
    7. **支払期限の記録**: 支払期限は `memo` に記録する
    8. **源泉徴収**: 士業・個人事業主への支払いで源泉徴収がある場合、源泉徴収額は別仕訳（借方: 買掛金/未払金、貸方: 預り金）として処理する。`memo` に「源泉徴収あり」と記載する
    9. **非定型フォーマットへの対応**: 請求書のレイアウトは発行元ごとに異なる。ラベルの位置や表現が異なっても、文脈から適切に情報を読み取る

    ### 出力 JSON 仕様

    以下の構造で JSON を出力してください。JSON以外のテキストは含めないでください。

    ```json
    {
      "invoice_date": "YYYY-MM-DD",
      "vendor_name": "請求元名",
      "invoice_number": "請求書番号",
      "has_invoice_number": true,
      "invoice_registration_number": "T1234567890123",
      "generated_at": "ISO 8601 形式（JST）",
      "transactions": [
        {
          "transaction_no": 1,
          "date": "YYYY-MM-DD",
          "debit_account": "勘定科目名",
          "debit_sub_account": "",
          "debit_department": "",
          "debit_partner": "取引先名",
          "debit_tax_category": "課税仕入10%（インボイス）",
          "debit_invoice": "T1234567890123",
          "debit_amount": 0,
          "credit_account": "未払金",
          "credit_sub_account": "",
          "credit_department": "",
          "credit_partner": "取引先名",
          "credit_tax_category": "",
          "credit_invoice": "",
          "credit_amount": 0,
          "description": "取引先名 請求内容の要約",
          "tag": "invoice",
          "memo": "",
          "status": "ok"
        }
      ],
      "summary": {
        "total_transactions": 0,
        "total_amount": 0,
        "review_required_count": 0,
        "accounts_breakdown": {}
      }
    }
    ```
  PROMPT

  def initialize(pdf:, client_code:)
    @pdf = pdf
    @client_code = client_code
  end

  def call
    unless ENV["ANTHROPIC_API_KEY"].present?
      return Result.new(success: false, data: {}, error: "ANTHROPIC_API_KEY が設定されていません", reason: :config_error)
    end

    pdf_binary = read_pdf_binary
    account_master_context = build_account_master_context
    user_prompt = build_user_prompt(account_master_context)
    pages = parse_pdf_pages(pdf_binary)

    process_with_adaptive_batch_size(pages, user_prompt)
  rescue Anthropic::Errors::APIError => e
    Result.new(success: false, data: {}, error: "Anthropic API エラー: #{e.message}", reason: :api_error)
  rescue JSON::ParserError => e
    Result.new(success: false, data: {}, error: "JSON パースエラー: #{e.message}", reason: :parse_error)
  rescue StandardError => e
    Result.new(success: false, data: {}, error: "予期しないエラー: #{e.message}", reason: :unexpected_error)
  end

  private

  def read_pdf_binary
    if @pdf.respond_to?(:download)
      @pdf.download
    elsif @pdf.respond_to?(:read)
      @pdf.rewind if @pdf.respond_to?(:rewind)
      @pdf.read
    else
      File.binread(@pdf.to_s)
    end
  end

  def parse_pdf_pages(pdf_binary)
    CombinePDF.parse(pdf_binary).pages
  end

  def build_batch_pdfs(pages, batch_size)
    pages.each_slice(batch_size).map do |page_group|
      batch_pdf = CombinePDF.new
      page_group.each { |page| batch_pdf << page }
      batch_pdf.to_pdf
    end
  end

  def process_with_adaptive_batch_size(pages, user_prompt)
    batch_size = [ INITIAL_BATCH_SIZE, pages.size ].min

    loop do
      batch_pdfs = build_batch_pdfs(pages, batch_size)
      batch_results = []
      max_tokens_hit = false

      batch_pdfs.each_with_index do |batch_pdf_binary, index|
        batch_pdf_data = Base64.strict_encode64(batch_pdf_binary)
        previous_transaction_count = batch_results.sum { |r| r[:transactions]&.size || 0 }

        start_page = index * batch_size + 1
        end_page = [ start_page + batch_size - 1, pages.size ].min

        prompt = if batch_pdfs.size == 1
          user_prompt
        else
          <<~CONTEXT
            #{user_prompt}

            【バッチ処理情報】
            このPDFは全#{pages.size}ページ中のページ#{start_page}〜#{end_page}です（バッチ#{index + 1}/#{batch_pdfs.size}）。
            前のバッチまでに#{previous_transaction_count}件の取引を処理済みです。transaction_noは#{previous_transaction_count + 1}から開始してください。
          CONTEXT
        end

        response = call_api(batch_pdf_data, prompt)

        if response.respond_to?(:stop_reason) && response.stop_reason == "max_tokens"
          max_tokens_hit = true
          break
        end

        data = parse_response(response)
        batch_results << data
      end

      if max_tokens_hit
        new_batch_size = batch_size / 2
        if new_batch_size < MIN_BATCH_SIZE
          return Result.new(
            success: false, data: {}, reason: :api_error,
            error: "バッチサイズ#{batch_size}でもmax_tokensに達しました。PDFのページあたりの情報量が多すぎます"
          )
        end
        batch_size = new_batch_size
        next
      end

      if batch_results.size == 1
        return Result.new(success: true, data: batch_results.first, error: nil, reason: nil)
      else
        merged_data = merge_batch_results(batch_results)
        return Result.new(success: true, data: merged_data, error: nil, reason: nil)
      end
    end
  end

  def merge_batch_results(batch_results)
    all_transactions = batch_results.flat_map { |r| r[:transactions] || [] }

    all_transactions.each_with_index do |txn, index|
      txn[:transaction_no] = index + 1
    end

    total_amount = all_transactions.sum { |t| t[:debit_amount].to_i }
    review_required_count = all_transactions.count { |t| t[:status] == "review_required" }

    accounts_breakdown = {}
    all_transactions.each do |t|
      account = t[:debit_account]
      accounts_breakdown[account] = (accounts_breakdown[account] || 0) + t[:debit_amount].to_i
    end

    {
      invoice_date: batch_results.first[:invoice_date],
      vendor_name: batch_results.first[:vendor_name],
      invoice_number: batch_results.first[:invoice_number],
      has_invoice_number: batch_results.first[:has_invoice_number],
      invoice_registration_number: batch_results.first[:invoice_registration_number],
      generated_at: Time.current.iso8601,
      transactions: all_transactions,
      summary: {
        total_transactions: all_transactions.size,
        total_amount: total_amount,
        review_required_count: review_required_count,
        accounts_breakdown: accounts_breakdown
      }
    }
  end

  def call_api(pdf_data, prompt_text)
    client.messages.create(
      model: ENV.fetch("ANTHROPIC_MODEL", "claude-sonnet-4-6"),
      max_tokens: 65536,
      system: SYSTEM_PROMPT,
      messages: [{
        role: "user",
        content: [
          {
            type: "document",
            source: {
              type: "base64",
              media_type: "application/pdf",
              data: pdf_data
            }
          },
          {
            type: "text",
            text: prompt_text
          }
        ]
      }]
    )
  end

  def parse_response(response)
    text_block = response.content.find { |c| c.respond_to?(:type) && c.type.to_s == "text" }
    text = text_block&.respond_to?(:text) ? text_block.text : text_block.to_s
    raise JSON::ParserError, "APIからテキスト応答がありませんでした" if text.blank?

    json_str = extract_json(text)
    JSON.parse(json_str, symbolize_names: true)
  end

  def build_account_master_context
    masters = AccountMaster.for_client(@client_code).for_source("invoice").order(confidence_score: :desc)
    return "" if masters.empty?

    lines = masters.map do |m|
      parts = []
      parts << "店舗名キーワード: #{m.merchant_keyword}" if m.merchant_keyword.present?
      parts << "取引内容キーワード: #{m.description_keyword}" if m.description_keyword.present?
      parts << "→ 勘定科目: #{m.account_category}"
      parts << "(信頼度: #{m.confidence_score}%)" if m.confidence_score
      parts.join(" / ")
    end

    <<~CONTEXT

      ### 優先度0: 確定マッチング（AccountMasterデータベース）

      以下はクライアント固有の勘定科目マッピングです。これらは最優先で適用してください。

      #{lines.join("\n")}
    CONTEXT
  end

  def build_user_prompt(account_master_context)
    prompt = "添付の請求書PDFを読み取り、仕訳台帳データに変換してください。JSONのみで出力してください。"
    prompt += account_master_context if account_master_context.present?
    prompt
  end

  def extract_json(text)
    if text =~ /```(?:json)?\s*\n(.*)\n\s*```/m
      $1.strip
    elsif (start = text.index("{")) && (finish = text.rindex("}"))
      text[start..finish]
    else
      text.strip
    end
  end

  def client
    @client ||= Anthropic::Client.new(timeout: 300.0)
  end
end
