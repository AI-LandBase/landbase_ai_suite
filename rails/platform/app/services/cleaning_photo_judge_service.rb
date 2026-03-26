require "image_processing/vips"

class CleaningPhotoJudgeService
  Result = Data.define(:success, :result, :feedback, :error) do
    alias_method :success?, :success
  end

  MAX_IMAGE_LONG_EDGE = 1568
  VALID_RESULTS = %w[ok ng].freeze

  SYSTEM_PROMPT = <<~PROMPT
    あなたは宿泊施設の清掃品質を検査する専門家です。
    清掃スタッフが撮影した写真を見て、指定された清掃タスクが完了基準を満たしているか判定してください。

    ## 判定ルール
    - 完了基準（チェックポイント）を満たしている場合: "ok"
    - 完了基準を満たしていない場合: "ng"
    - 迷った場合は "ng" とし、具体的な確認ポイントを修正指示として提示してください

    ## 出力形式（JSON のみ、他のテキストは含めないでください）
    {
      "result": "ok" or "ng",
      "feedback": "判定理由（OKの場合は確認できた点、NGの場合は具体的な修正指示）"
    }
  PROMPT

  def initialize(photos:, task:, description:, checkpoint:)
    @photos = Array(photos)
    @task = task
    @description = description
    @checkpoint = checkpoint
  end

  def call
    unless ENV["ANTHROPIC_API_KEY"].present?
      return Result.new(success: false, result: nil, feedback: nil, error: "ANTHROPIC_API_KEY が設定されていません")
    end

    content = build_content
    response = client.messages.create(
      model: ENV.fetch("ANTHROPIC_MODEL", "claude-sonnet-4-6"),
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: [{ role: "user", content: content }]
    )

    text_block = response.content.find { |c| c.respond_to?(:type) && c.type.to_s == "text" }
    text = text_block&.respond_to?(:text) ? text_block.text : text_block.to_s
    raise JSON::ParserError, "APIからテキスト応答がありませんでした" if text.blank?

    json_str = extract_json(text)
    data = JSON.parse(json_str, symbolize_names: true)

    normalized_result = data[:result].to_s.downcase.strip
    unless VALID_RESULTS.include?(normalized_result)
      return Result.new(success: false, result: nil, feedback: nil,
                        error: "AIの判定結果が不正です: #{data[:result]}")
    end

    Result.new(
      success: true,
      result: normalized_result,
      feedback: data[:feedback],
      error: nil
    )
  rescue Anthropic::Errors::APIError => e
    Result.new(success: false, result: nil, feedback: nil, error: "Anthropic API エラー: #{e.message}")
  rescue JSON::ParserError => e
    Result.new(success: false, result: nil, feedback: nil, error: "JSON パースエラー: #{e.message}")
  rescue StandardError => e
    Result.new(success: false, result: nil, feedback: nil, error: "予期しないエラー: #{e.message}")
  end

  private

  def build_content
    content = []

    @photos.each_with_index do |photo, i|
      resized = resize_image(photo)
      image_data = Base64.strict_encode64(resized[:data])

      content << {
        type: "image",
        source: {
          type: "base64",
          media_type: resized[:media_type],
          data: image_data
        }
      }

      content << { type: "text", text: "写真#{i + 1}" } if @photos.size > 1
    end

    content << {
      type: "text",
      text: <<~TEXT
        以下の清掃タスクの完了状態を判定してください。

        【タスク】#{@task}
        【作業内容】#{@description}
        【チェックポイント（完了基準）】#{@checkpoint}

        JSONのみで出力してください。
      TEXT
    }

    content
  end

  def resize_image(photo)
    source = if photo.respond_to?(:tempfile)
               photo.tempfile.path
             elsif photo.respond_to?(:path)
               photo.path
             else
               photo.to_s
             end

    processor = ImageProcessing::Vips.source(source)
    result = processor.resize_to_limit(MAX_IMAGE_LONG_EDGE, MAX_IMAGE_LONG_EDGE)
                      .convert("jpeg")
                      .saver(quality: 80)
                      .call
    { data: File.binread(result.path), media_type: "image/jpeg" }
  ensure
    if result.respond_to?(:close)
      result.close
      result.unlink if result.respond_to?(:unlink)
    end
    photo.rewind if photo.respond_to?(:rewind)
  end

  def extract_json(text)
    if text =~ /```(?:json)?\s*\n?(.*?)\n?```/m
      $1.strip
    else
      text.strip
    end
  end

  def client
    @client ||= Anthropic::Client.new(timeout: 30.0)
  end
end
