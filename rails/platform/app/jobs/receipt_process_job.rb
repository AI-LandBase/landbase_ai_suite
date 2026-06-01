class ReceiptProcessJob < ApplicationJob
  include JournalEntryCreator

  class RetryableError < StandardError; end

  queue_as :default

  retry_on RetryableError, wait: 5.seconds, attempts: 2 do |job, exception|
    batch = StatementBatch.find_by(id: job.arguments.first)
    batch&.update(status: "failed", error_message: "リトライ上限到達: #{exception.message}")
  end

  discard_on ActiveRecord::RecordNotFound

  def perform(statement_batch_id)
    batch = StatementBatch.find(statement_batch_id)
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
          batch.update!(
            status: "completed",
            summary: result.data[:summary] || {},
            error_message: nil
          )
        end
      rescue DuplicateFound => e
        batch.update!(status: "duplicate", error_message: "重複検知: 既存 JE id=#{e.existing_entry.id}")
      rescue ActiveRecord::RecordInvalid => e
        batch.update(status: "failed", error_message: "仕訳データの保存に失敗: #{e.message}")
      end
    elsif result.retryable?
      raise RetryableError, result.error
    else
      batch.update!(status: "failed", error_message: result.error)
    end
  end
end
