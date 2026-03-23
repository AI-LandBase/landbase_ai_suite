require "combine_pdf"

class BankStatementProcessorService
  NON_RETRYABLE_REASONS = %i[config_error].freeze

  Result = Data.define(:success, :data, :error, :reason) do
    alias_method :success?, :success
    def retryable? = !success && !NON_RETRYABLE_REASONS.include?(reason)
  end

  INITIAL_BATCH_SIZE = 20
  MIN_BATCH_SIZE = 5

  SYSTEM_PROMPT = <<~PROMPT
    あなたは日本の経理・簿記の専門家です。以下のルールに厳密に従い、銀行入出金明細 PDF から抽出した取引データを仕訳台帳データに変換してください。

    ### 前提知識

    - **複式簿記**: すべての取引は借方・貸方の両方に同額を記録する
    - **出金（引落・振込等）の場合**:
      - 借方: 費用科目（取引内容から推定）
      - 貸方: 勘定科目「普通預金」、補助科目「{銀行名}」
    - **入金（振込入金等）の場合**:
      - 借方: 勘定科目「普通預金」、補助科目「{銀行名}」
      - 貸方: 収益/債権科目（取引内容から推定）
    - **銀行名の特定**: PDF の表紙・ヘッダー等から銀行名と支店名を読み取る

    ### 出金/入金判定ルール

    銀行明細 PDF では各行に「出金額」「入金額」のいずれかに金額が記載される。

    | 区分 | 判定基準 | 借方 | 貸方 |
    |------|----------|------|------|
    | 出金 | 「出金額」「お引出し」欄に金額あり | 費用科目等（推定） | 普通預金/{銀行名} |
    | 入金 | 「入金額」「お預入れ」欄に金額あり | 普通預金/{銀行名} | 収益/債権科目（推定） |

    ### 勘定科目推定ルール

    取引の摘要から、以下のルールで勘定科目を推定する。銀行明細の摘要は**半角カタカナ**が多いため、半角カタカナでのマッチングを優先する。

    #### 出金時の推定ルール（借方: 費用科目等、貸方: 普通預金）

    | キーワード（半角カタカナ） | 借方勘定科目 | 備考 |
    |---|---|---|
    | NTTﾃﾞﾝﾜﾘﾖｳ, ｿﾌﾄﾊﾞﾝｸ, KDDI | 通信費 | 通信料引落 |
    | ﾃﾞﾝｷﾘﾖｳ, ｵｷﾅﾜﾃﾞﾝﾘﾖｸ | 水道光熱費 | 電気料金 |
    | ｶﾞｽﾘﾖｳ | 水道光熱費 | ガス料金 |
    | ｽｲﾄﾞｳﾘﾖｳ | 水道光熱費 | 水道料金 |
    | ｺﾞﾍﾝｻｲ | 長期借入金 | 借入返済 |
    | PE ｷﾖｳﾊﾞｼｾﾞｲﾑｼﾖ, ｾﾞｲﾑｼﾖ | 租税公課 | 税金支払 |
    | ﾃｽｳﾘﾖｳ, ﾌﾘｺﾐﾃｽｳﾘﾖｳ | 支払手数料 | 課税仕入10% |
    | ｱﾒﾘｶﾝｴｷｽﾌﾟﾚｽ, ｺｳｻﾞﾌﾘｶｴ | 未払金 | クレカ引落（補助科目にカード名を記載） |
    | ﾔﾁﾝ | 地代家賃 | 家賃支払 |
    | ｷﾕｳﾖ | 給与 | 給与支払 |
    | ｷﾞﾖｳﾑｲﾀｸﾋ | 外注費 | 業務委託費支払 |
    | ｼﾔｶｲﾎｹﾝ | 法定福利費 | 社会保険料 |
    | ﾎｹﾝﾘﾖｳ | 保険料 | 非課税 |

    #### 入金時の推定ルール（借方: 普通預金、貸方: 収益/債権科目）

    | キーワード | 貸方勘定科目 | 備考 |
    |---|---|---|
    | ﾌﾘｺﾐ + 法人名/個人名 | 売掛金 | 売掛金回収 |
    | ﾘｿｸ | 受取利息 | 非課税 |
    | その他入金 | review_required | `status` を `"review_required"` に設定 |

    #### AI 推論（低精度）

    上記ルールでマッチしない場合は、摘要から最も適切な勘定科目を推論する。ただし、推論に自信がない場合は `status` を `"review_required"` に設定し、`memo` に推論理由を記載する。

    ### 消費税率判定ルール

    #### 課税仕入10%（デフォルト）

    - `debit_tax_category`（出金時）: `"課税仕入10%（非インボイス）"`
    - ほとんどの出金取引はこちらに該当
    - 銀行明細にはインボイス番号が記載されないため、デフォルトは「非インボイス」とする

    #### 非課税

    - `debit_tax_category`: `"非課税仕入"`
    - 以下に該当する場合に適用:

    | 対象 | キーワード例 |
    |---|---|
    | 受取利息 | ﾘｿｸ |
    | 社会保険料 | ｼﾔｶｲﾎｹﾝ |
    | 租税公課 | ｾﾞｲﾑｼﾖ |
    | 保険料 | ﾎｹﾝﾘﾖｳ |

    #### 対象外

    - `debit_tax_category`: `"対象外"`
    - 以下に該当する場合に適用:

    | 対象 | キーワード例 |
    |---|---|
    | 給与 | ｷﾕｳﾖ |
    | 借入返済（元金） | ｺﾞﾍﾝｻｲ |
    | クレカ引落 | ｱﾒﾘｶﾝｴｷｽﾌﾟﾚｽ, ｺｳｻﾞﾌﾘｶｴ |

    #### その他注意事項

    - 銀行明細の取引は公共料金・借入返済・振込手数料等が中心のため、海外SaaS やリバースチャージが発生するケースは少ない
    - 入金時の貸方税区分は通常空文字とする（売掛金回収は課税対象外）。ただし、受取利息（ﾘｿｸ）の場合は `credit_tax_category` を `"非課税売上"` に設定する
    - 判断が困難な場合は `"課税仕入10%（非インボイス）"` を適用し、`memo` に「税率要確認」と記載する

    ### 処理上の注意事項

    1. **金額の扱い**: PDF に記載された金額をそのまま使用する。借方金額と貸方金額は必ず一致させる
    2. **日付の扱い**: PDF の日付を YYYY-MM-DD 形式に変換する。年が省略されている場合は明細期間から推定する
    3. **摘要の半角カタカナ**: 銀行明細の摘要は半角カタカナが多い。PDF から抽出した摘要テキストをそのまま `description` に設定する（全角変換は不要）
    4. **銀行名・支店名**: PDF の表紙やヘッダーから銀行名・支店名を読み取り、`bank_name`・`branch_name` およびすべての普通預金の補助科目に反映する
    5. **出金/入金の判定**: 「出金額」「入金額」の列を必ず確認し、正しい方向で仕訳する。出金と入金で借方・貸方が逆転するため、特に注意する
    6. **クレカ引落**: ｱﾒﾘｶﾝｴｷｽﾌﾟﾚｽ、ｺｳｻﾞﾌﾘｶｴ等のクレカ引落は、借方を「未払金」（補助科目にカード名）とする。消費税区分は「対象外」
    7. **借入返済**: ｺﾞﾍﾝｻｲは「長期借入金」として処理する。元金部分は消費税「対象外」。利息部分が分離できる場合は「支払利息」として別仕訳にする
    8. **複数ページ**: PDF が複数ページの場合、全ページの取引を連番で通しナンバリングする
    9. **残高の検証**: 可能であれば、抽出した取引金額と残高の整合性を確認する。不整合がある場合は `memo` に「残高不整合：要確認」と記載する

    ### 出力 JSON 仕様

    以下の構造で JSON を出力してください。JSON以外のテキストは含めないでください。

    ```json
    {
      "statement_period": "YYYY年M月",
      "bank_name": "銀行名",
      "branch_name": "支店名",
      "generated_at": "ISO 8601 形式（JST）",
      "transactions": [
        {
          "transaction_no": 1,
          "date": "YYYY-MM-DD",
          "debit_account": "勘定科目名",
          "debit_sub_account": "",
          "debit_department": "",
          "debit_partner": "取引先名",
          "debit_tax_category": "課税仕入10%（非インボイス）",
          "debit_invoice": "",
          "debit_amount": 0,
          "credit_account": "普通預金",
          "credit_sub_account": "銀行名",
          "credit_department": "",
          "credit_partner": "",
          "credit_tax_category": "",
          "credit_invoice": "",
          "credit_amount": 0,
          "description": "摘要テキスト",
          "tag": "bank",
          "memo": "",
          "status": "ok"
        }
      ],
      "summary": {
        "total_transactions": 0,
        "total_withdrawals": 0,
        "total_deposits": 0,
        "review_required_count": 0,
        "accounts_breakdown": {}
      }
    }
    ```
  PROMPT

  def initialize(pdf:, client_code:, bank_name: nil)
    @pdf = pdf
    @client_code = client_code
    @bank_name = bank_name
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
            前のページからの銀行名・支店名情報がある場合は引き継いでください。
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

    total_withdrawals = all_transactions.select { |t| t[:credit_account] == "普通預金" }.sum { |t| t[:debit_amount].to_i }
    total_deposits = all_transactions.select { |t| t[:debit_account] == "普通預金" }.sum { |t| t[:debit_amount].to_i }
    review_required_count = all_transactions.count { |t| t[:status] == "review_required" }

    accounts_breakdown = {}
    all_transactions.each do |t|
      account = t[:debit_account]
      accounts_breakdown[account] = (accounts_breakdown[account] || 0) + t[:debit_amount].to_i
    end

    {
      statement_period: batch_results.first[:statement_period],
      bank_name: batch_results.first[:bank_name],
      branch_name: batch_results.first[:branch_name],
      generated_at: Time.current.iso8601,
      transactions: all_transactions,
      summary: {
        total_transactions: all_transactions.size,
        total_withdrawals: total_withdrawals,
        total_deposits: total_deposits,
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
      messages: [ {
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
      } ]
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
    masters = AccountMaster.for_client(@client_code).for_source("bank").order(confidence_score: :desc)
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
    prompt = "添付の銀行入出金明細PDFを読み取り、全取引を仕訳台帳データに変換してください。JSONのみで出力してください。"
    prompt += "銀行名: #{@bank_name}" if @bank_name.present?
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
