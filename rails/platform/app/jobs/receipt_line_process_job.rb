class ReceiptLineProcessJob < ApplicationJob
  include JournalEntryCreator

  class RetryableError < StandardError; end

  queue_as :default

  retry_on RetryableError, wait: 5.seconds, attempts: 2 do |job, exception|
    args = job.arguments.first
    client = Client.find_by(id: args[:client_id])
    if client
      batch = client.statement_batches.where(status: "processing", source_type: "receipt").order(created_at: :desc).first
      batch&.update!(status: "failed", error_message: "リトライ上限到達: #{exception.message}")
    end
    LineMessagingService.push(args[:line_user_id], "処理中にエラーが発生しました。もう一度お試しください。")
  end

  discard_on ActiveRecord::RecordNotFound

  def perform(client_id:, message_id:, line_user_id:)
    client = Client.find(client_id)
    @line_service = LineMessagingService.new

    image_binary = @line_service.get_content(message_id)
    unless image_binary
      @line_service.push(line_user_id, "画像の取得に失敗しました。もう一度お試しください。")
      return
    end

    fingerprint = Digest::SHA256.hexdigest(image_binary)

    existing = StatementBatch.find_by(client: client, pdf_fingerprint: fingerprint)
    if existing
      if existing.status == "processing"
        process_receipt(existing, line_user_id)
        return
      end
      @line_service.push(line_user_id, "この画像は既に処理済みです。")
      return
    end

    batch = client.statement_batches.create!(
      source_type: "receipt",
      status: "processing",
      pdf_fingerprint: fingerprint
    )

    batch.pdf.attach(
      io: StringIO.new(image_binary),
      filename: "receipt_#{message_id}.jpg",
      content_type: detect_content_type(image_binary)
    )

    @line_service.push(line_user_id, "領収書を受け付けました。処理中です...")

    process_receipt(batch, line_user_id)
  end

  private

  def process_receipt(batch, line_user_id)
    return unless batch.status == "processing"

    service = ReceiptProcessorService.new(
      image: batch.pdf,
      client_code: batch.client.code
    )
    result = service.call

    if result.success?
      begin
        ActiveRecord::Base.transaction do
          create_journal_entries(batch, result.data)
          batch.update!(status: "completed", summary: result.data[:summary] || {})
        end

        @line_service.push(line_user_id, format_success_message(result.data))
      rescue DuplicateFound => e
        batch.update!(status: "duplicate", error_message: "重複検知: 既存 JE id=#{e.existing_entry.id}")
        @line_service.push(line_user_id, format_duplicate_message(e.existing_entry))
      end
    elsif result.retryable?
      raise RetryableError, result.error
    else
      batch.update!(status: "failed", error_message: result.error)

      message = case result.reason
      when :non_receipt
        "領収書またはレシートの画像を送信してください。"
      else
        "処理中にエラーが発生しました。もう一度お試しください。"
      end
      @line_service.push(line_user_id, message)
    end
  end

  def format_duplicate_message(existing_entry)
    debit_line = existing_entry.journal_entry_lines.find_by(side: "debit")
    partner = debit_line&.partner.presence || existing_entry.description
    amount = debit_line&.amount

    lines = ["このレシートは処理済みです。"]
    lines << "📅 #{existing_entry.date} に登録"
    lines << "🏪 #{partner}" if partner.present?
    lines << "💰 ¥#{amount}" if amount
    lines.join("\n")
  end

  def format_success_message(data)
    txns = data[:transactions] || []
    first_txn = txns.first
    return "領収書を処理しました。" unless first_txn

    total = data.dig(:summary, :total_amount) || txns.sum { |t| t[:debit_amount].to_i }

    lines = ["📝 領収書を処理しました", ""]
    lines << "📅 日付: #{first_txn[:date]}"
    lines << "🏪 支払先: #{first_txn[:debit_partner]}" if first_txn[:debit_partner].present?
    lines << "💰 合計金額: ¥#{ActiveSupport::NumberHelper.number_to_delimited(total)}"
    if txns.size > 1
      lines << "📂 内訳: #{txns.size}件の仕訳"
    else
      lines << "📂 勘定科目: #{first_txn[:debit_account]}"
    end
    lines << "🔍 判定元: #{first_txn[:status] == "review_required" ? "AI推論（要確認）" : "AIマッチング"}"
    lines.join("\n")
  end

  def detect_content_type(binary)
    binary = binary.dup.force_encoding(Encoding::ASCII_8BIT)
    if binary.start_with?("\xFF\xD8\xFF".b)
      "image/jpeg"
    elsif binary.start_with?("\x89PNG\r\n\x1A\n".b)
      "image/png"
    elsif binary.start_with?("RIFF".b) && binary[8, 4] == "WEBP".b
      "image/webp"
    else
      "application/octet-stream"
    end
  end
end
