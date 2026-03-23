class InvoiceProcessJob < ApplicationJob
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

    service = InvoiceProcessorService.new(
      pdf: batch.pdf,
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
      rescue ActiveRecord::RecordInvalid => e
        batch.update(status: "failed", error_message: "仕訳データの保存に失敗: #{e.message}")
      end
    elsif result.retryable?
      raise RetryableError, result.error
    else
      batch.update!(status: "failed", error_message: result.error)
    end
  end

  private

  def create_journal_entries(batch, data)
    source_period = if data[:invoice_date].present?
      date = Date.parse(data[:invoice_date])
      "#{date.year}年#{date.month}月"
    end

    transactions = data[:transactions] || []
    transactions.each do |txn|
      batch.journal_entries.create!(
        client: batch.client,
        source_type: batch.source_type,
        source_period: source_period,
        transaction_no: txn[:transaction_no],
        date: txn[:date],
        description: txn[:description] || "",
        tag: txn[:tag] || "invoice",
        memo: txn[:memo] || "",
        cardholder: "",
        status: txn[:status] || "ok",
        journal_entry_lines_attributes: [
          {
            side: "debit",
            account: txn[:debit_account],
            sub_account: txn[:debit_sub_account] || "",
            department: txn[:debit_department] || "",
            partner: txn[:debit_partner] || "",
            tax_category: txn[:debit_tax_category] || "",
            invoice: txn[:debit_invoice] || "",
            amount: txn[:debit_amount]
          },
          {
            side: "credit",
            account: txn[:credit_account],
            sub_account: txn[:credit_sub_account] || "",
            department: txn[:credit_department] || "",
            partner: txn[:credit_partner] || "",
            tax_category: txn[:credit_tax_category] || "",
            invoice: txn[:credit_invoice] || "",
            amount: txn[:credit_amount]
          }
        ]
      )
    end
  end
end
