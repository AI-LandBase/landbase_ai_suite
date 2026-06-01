class LineWebhookController < ApplicationController
  skip_before_action :authenticate_user!
  skip_forgery_protection

  rescue_from ActionDispatch::Http::Parameters::ParseError do
    head :bad_request
  end

  before_action :verify_line_signature

  def receive
    events = JSON.parse(raw_body)["events"] || []

    events.each { |event| handle_event(event) }

    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def raw_body
    @raw_body ||= begin
      body = request.body.read
      request.body.rewind
      body
    end
  end

  def verify_line_signature
    signature = request.headers["X-Line-Signature"]
    unless signature.present?
      head :unauthorized
      return
    end

    channel_secret = ENV.fetch("LINE_CHANNEL_SECRET")
    digest = OpenSSL::HMAC.digest("SHA256", channel_secret, raw_body)
    expected = Base64.strict_encode64(digest)

    unless ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      head :unauthorized
      return
    end
  end

  def handle_event(event)
    case event["type"]
    when "message"
      handle_message(event) if event.dig("message", "type") == "image"
    when "follow"
      handle_follow(event)
    end
  end

  def handle_message(event)
    line_user_id = event.dig("source", "userId")
    return unless line_user_id.present?

    client = LineFollower.find_by(line_user_id: line_user_id)&.client

    unless client
      LineMessagingService.reply(
        event["replyToken"],
        "このLINEアカウントは未登録です。一度ブロックを解除して友だち追加し直してください。"
      )
      return
    end

    ReceiptLineProcessJob.perform_later(
      client_id: client.id,
      message_id: event.dig("message", "id"),
      line_user_id: line_user_id
    )
  end

  def handle_follow(event)
    line_user_id = event.dig("source", "userId")
    return unless line_user_id.present?

    client = default_client

    unless client
      LineMessagingService.reply(
        event["replyToken"],
        "友だち追加ありがとうございます！\nサービスの初期設定が完了していません。管理者にお問い合わせください。"
      )
      return
    end

    LineFollower.find_or_create_by!(line_user_id: line_user_id) do |follower|
      follower.client = client
    end

    LineMessagingService.reply(
      event["replyToken"],
      "#{client.name}さん、友だち追加ありがとうございます！\n領収書・レシートの画像を送信すると、自動で仕訳データを作成します。"
    )
  end

  def default_client
    code = ENV["LINE_DEFAULT_CLIENT_CODE"]
    return nil unless code.present?

    Client.find_by(code: code)
  end
end
