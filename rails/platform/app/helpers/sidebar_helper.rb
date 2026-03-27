module SidebarHelper
  def sidebar_items(client)
    items = [
      { label: "ダッシュボード", path: client_path(client), icon: "dashboard", controller: "clients" },
      { label: "仕訳台帳", path: journal_entries_path(client_code: client.code), icon: "journal", controller: "journal_entries" },
      { label: "Amex明細処理", path: new_amex_statement_path(client_code: client.code), icon: "credit_card", controller: "amex_statements" },
      { label: "銀行明細処理", path: new_bank_statement_path(client_code: client.code), icon: "bank", controller: "bank_statements" },
      { label: "請求書処理", path: new_invoice_path(client_code: client.code), icon: "invoice", controller: "invoices" },
      { label: "月次レポート", path: monthly_reports_path(client_code: client.code), icon: "report", controller: "monthly_reports" }
    ]
    if client.feature_available?(:cleaning_manuals)
      items << { label: "清掃マニュアル", path: cleaning_manuals_path(client_code: client.code), icon: "cleaning", controller: "cleaning_manuals" }
    end
    items
  end

  def current_sidebar_item?(item)
    controller_name == item[:controller]
  end
end
