class ReceiptProcessorService
  NON_RETRYABLE_REASONS = %i[config_error non_receipt unsupported_format file_not_found].freeze

  Result = Data.define(:success, :data, :error, :reason) do
    alias_method :success?, :success
    def retryable? = !success && !NON_RETRYABLE_REASONS.include?(reason)
  end

  JPEG_MAGIC  = "\xFF\xD8\xFF".b.freeze
  PNG_MAGIC   = "\x89PNG\r\n\x1A\n".b.freeze
  RIFF_HEADER = "RIFF".b.freeze
  WEBP_FOURCC = "WEBP".b.freeze

  SYSTEM_PROMPT = <<~PROMPT
    あなたは日本の経理・簿記の専門家です。以下のルールに厳密に従い、領収書・レシートの画像から仕訳データを生成してください。

    ### ステップ1: 画像判定

    まず、画像が領収書・レシートであるか判定してください。
    - 領収書・レシートである → `is_receipt: true` として仕訳データを生成
    - 領収書・レシートでない（手書きメモ、名刺、風景写真等）→ `is_receipt: false` のみ返す

    境界ケース（手書きメモ、名刺等）は「領収書でない」側に倒してください。

    ### ステップ2: 領収書データ抽出ルール

    領収書・レシート画像から以下の情報を読み取る。

    | 抽出項目 | 抽出方法 | 備考 |
    |---|---|---|
    | 日付 | 「日付」「発行日」等のラベル付近、またはレシート上部 | YYYY-MM-DD に変換 |
    | 支払先名 | 店舗名・屋号・ロゴ | 正式名称を使用 |
    | 合計金額（税込） | 「合計」「お支払い」「計」等 | 税込金額を使用 |
    | 消費税額 | 「消費税」「税額」「内税」等 | 明記されている場合のみ |
    | インボイス番号 | T+13桁の数字（例: T1234567890123） | 登録番号・適格請求書番号 |

    ### 勘定科目推定ルール

    支払先名・明細内容から、以下のルールで借方勘定科目を推定する。

    #### キーワードベースの推定（高精度）

    | 支払先・内容キーワード | 借方勘定科目 | 備考 |
    |---|---|---|
    | スーパー, 食材, 食品, 八百屋, 魚屋, 精肉 | 仕入高 | 飲食業の食材仕入 |
    | レストラン, 飲食, カフェ, 居酒屋 | 接待交際費 | 会食・接待 |
    | タクシー, バス, 電車, 駐車場, ガソリン, 高速道路 | 旅費交通費 | |
    | 文具, 事務用品, コピー, 印刷 | 消耗品費 | |
    | 薬局, ドラッグストア, 洗剤, 清掃用品 | 消耗品費 | |
    | ホームセンター, 工具, 修繕, リフォーム | 修繕費 | |
    | 宅配便, 郵便, 切手, レターパック | 通信費 | |
    | 電話, インターネット, Wi-Fi | 通信費 | |
    | 保険 | 保険料 | |

    #### AI 推論（低精度）

    上記ルールでマッチしない場合は、支払先名・明細内容から最も適切な勘定科目を推論する。推論に自信がない場合は `status` を `"review_required"` に設定し、`memo` に推論理由を記載する。

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

    - 食品・飲料（酒類を除く）に関する支払いは軽減税率8%を適用
    - それ以外はデフォルトで標準税率10%を適用

    ### 貸方勘定科目

    領収書・レシートの貸方は **「現金」** がデフォルトです（その場で支払い済みのため）。

    ### 処理上の注意事項

    1. **金額の扱い**: 税込合計金額を使用する。借方金額と貸方金額は必ず一致させる
    2. **日付の扱い**: YYYY-MM-DD 形式に変換
    3. **支払先名**: 画像に記載された正式名称をそのまま使用する
    4. **インボイス番号の検証**: T+13桁のパターンに一致するか確認する
    5. **判断が困難な場合**: 標準税率10%を適用し、`memo` に「税率要確認」と記載する

    ### 出力 JSON 仕様

    以下の構造で JSON を出力してください。JSON以外のテキストは含めないでください。

    #### 領収書の場合

    ```json
    {
      "is_receipt": true,
      "receipt_date": "YYYY-MM-DD",
      "vendor_name": "支払先名",
      "total_amount": 0,
      "tax_amount": 0,
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
          "debit_partner": "支払先名",
          "debit_tax_category": "課税仕入10%（インボイス）",
          "debit_invoice": "T1234567890123",
          "debit_amount": 0,
          "credit_account": "現金",
          "credit_sub_account": "",
          "credit_department": "",
          "credit_partner": "",
          "credit_tax_category": "",
          "credit_invoice": "",
          "credit_amount": 0,
          "description": "支払先名 摘要",
          "tag": "receipt",
          "memo": "",
          "status": "ok"
        }
      ],
      "summary": {
        "total_transactions": 1,
        "total_amount": 0,
        "review_required_count": 0,
        "accounts_breakdown": {}
      }
    }
    ```

    #### 領収書でない場合

    ```json
    {
      "is_receipt": false
    }
    ```
  PROMPT

  def initialize(image:, client_code:)
    @image = image
    @client_code = client_code
  end

  def call
    unless ENV["ANTHROPIC_API_KEY"].present?
      return Result.new(success: false, data: {}, error: "ANTHROPIC_API_KEY が設定されていません", reason: :config_error)
    end

    image_binary = read_image_binary
    media_type = detect_media_type(image_binary)
    unless media_type
      return Result.new(success: false, data: {}, error: "対応していない画像フォーマットです", reason: :unsupported_format)
    end

    image_data = Base64.strict_encode64(image_binary)
    account_master_context = build_account_master_context
    user_prompt = build_user_prompt(account_master_context)

    response = call_api(image_data, media_type, user_prompt)

    if response.respond_to?(:stop_reason) && response.stop_reason == "max_tokens"
      return Result.new(success: false, data: {}, error: "APIの応答がmax_tokensで切り詰められました", reason: :api_error)
    end

    data = parse_response(response)

    unless data[:is_receipt]
      return Result.new(success: false, data: {}, error: "領収書として認識できません", reason: :non_receipt)
    end

    Result.new(success: true, data: data, error: nil, reason: nil)
  rescue ActiveStorage::FileNotFoundError => e
    Result.new(success: false, data: {}, error: "画像ファイルが見つかりません: #{e.message}", reason: :file_not_found)
  rescue Anthropic::Errors::APIError => e
    Result.new(success: false, data: {}, error: "Anthropic API エラー: #{e.message}", reason: :api_error)
  rescue JSON::ParserError => e
    Result.new(success: false, data: {}, error: "JSON パースエラー: #{e.message}", reason: :parse_error)
  rescue StandardError => e
    Result.new(success: false, data: {}, error: "予期しないエラー: #{e.message}", reason: :unexpected_error)
  end

  private

  def read_image_binary
    if @image.respond_to?(:download)
      @image.download
    elsif @image.respond_to?(:read)
      @image.rewind if @image.respond_to?(:rewind)
      @image.read
    else
      File.binread(@image.to_s)
    end
  end

  def detect_media_type(binary)
    binary = binary.dup.force_encoding(Encoding::ASCII_8BIT)
    if jpeg?(binary)    then "image/jpeg"
    elsif png?(binary)  then "image/png"
    elsif webp?(binary) then "image/webp"
    end
  end

  def jpeg?(binary) = binary.start_with?(JPEG_MAGIC)
  def png?(binary)  = binary.start_with?(PNG_MAGIC)
  def webp?(binary) = binary.start_with?(RIFF_HEADER) && binary[8, 4] == WEBP_FOURCC

  def call_api(image_data, media_type, prompt_text)
    client.messages.create(
      model: ENV.fetch("ANTHROPIC_MODEL", "claude-sonnet-4-6"),
      max_tokens: 8192,
      system: SYSTEM_PROMPT,
      messages: [{
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: media_type,
              data: image_data
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
    masters = AccountMaster.for_client(@client_code).for_source("receipt").order(confidence_score: :desc)
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
    prompt = "添付の領収書・レシート画像を読み取り、仕訳データに変換してください。JSONのみで出力してください。"
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
    @client ||= Anthropic::Client.new(timeout: 120.0)
  end
end
