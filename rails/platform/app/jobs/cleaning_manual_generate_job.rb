class CleaningManualGenerateJob < ApplicationJob
  class RetryableError < StandardError; end

  queue_as :default

  retry_on RetryableError, wait: 5.seconds, attempts: 2 do |job, exception|
    manual_id = job.arguments.first
    manual = CleaningManual.find_by(id: manual_id)
    manual&.update(status: "failed", error_message: "リトライ上限到達: #{exception.message}")
  end

  discard_on ActiveRecord::RecordNotFound

  def perform(cleaning_manual_id, labels: [])
    manual = CleaningManual.find(cleaning_manual_id)
    return unless manual.status == "processing"

    image_wrappers = manual.images.map { |blob| BlobImageWrapper.new(blob) }

    begin
      service = CleaningManualGeneratorService.new(
        images: image_wrappers,
        property_name: manual.property_name,
        room_type: manual.room_type,
        labels: labels
      )
      result = service.call

      if result.success?
        manual.update!(manual_data: result.data, status: "draft", error_message: nil)
      elsif result.retryable?
        raise RetryableError, result.error
      else
        manual.update!(status: "failed", error_message: result.error)
      end
    ensure
      image_wrappers.each(&:close)
    end
  end
end
