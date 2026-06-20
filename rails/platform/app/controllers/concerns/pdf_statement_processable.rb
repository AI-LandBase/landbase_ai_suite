module PdfStatementProcessable
  extend ActiveSupport::Concern

  MAX_PDF_SIZE = 20.megabytes

  private

  # amex / bank / invoice の process_statement で共通の取り込みフロー。
  # source_type / job / noun（重複メッセージの名詞）のみ呼び出し側で差し替える。
  def ingest_pdf_statement(source_type:, job:, noun:)
    pdf = params[:pdf]
    return render_error("PDFファイルをアップロードしてください") if pdf.blank?

    unless Marcel::MimeType.for(pdf.tempfile, name: pdf.original_filename) == "application/pdf"
      return render_error("PDF形式のファイルのみ対応しています")
    end

    if pdf.size > MAX_PDF_SIZE
      return render_error("PDFファイルは20MB以下にしてください")
    end

    fingerprint = Digest::SHA256.hexdigest(pdf.read)
    pdf.rewind

    unless ActiveModel::Type::Boolean.new.cast(params[:force])
      existing = @current_client.statement_batches
        .where(pdf_fingerprint: fingerprint, status: %w[processing completed])
        .first
      if existing
        return render json: {
          error: existing.status == "processing" ? "この#{noun}は現在処理中です" : "この#{noun}は処理済みです",
          duplicate: true,
          existing_batch_id: existing.id,
          existing_batch_url: statement_batch_path(existing.id)
        }, status: :conflict
      end
    end

    batch = StatementBatch.ingest!(
      client: @current_client,
      source_type: source_type,
      fingerprint: fingerprint,
      attachable: pdf
    )

    cleanup_superseded_failed_batches(fingerprint)

    job.perform_later(batch.id)
    render json: { id: batch.id, status: "processing" }, status: :accepted
  end

  # 取り込みに成功した（completed になりうる）ファイルと同一 fingerprint の、
  # 放置された failed バッチを自テナントスコープで掃除する。
  # processing / completed は対象外（failed のみ）。dependent: :destroy で関連仕訳も連動削除される。
  def cleanup_superseded_failed_batches(fingerprint)
    @current_client.statement_batches
      .where(pdf_fingerprint: fingerprint, status: "failed")
      .destroy_all
  end
end
