module JournalEntryExportable
  extend ActiveSupport::Concern

  private

  def send_journal_csv(entries, format_type:)
    case format_type
    when "yayoi_single"
      csv_data = YayoiExportService.new.export_single_entry(entries)
      mark_entries_exported(entries)
      send_data csv_data,
                filename: "journal_entries_yayoi_single_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv",
                type: "text/csv; charset=windows-31j"
    when "csv", nil, ""
      csv = "\uFEFF" + entries.to_csv
      mark_entries_exported(entries)
      send_data csv, filename: "journal_entries_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv",
                     type: "text/csv; charset=utf-8"
    else
      head :bad_request
    end
  end

  def mark_entries_exported(entries)
    JournalEntry.where(id: entries.except(:order).select(:id)).update_all(exported_at: Time.current)
  end
end
