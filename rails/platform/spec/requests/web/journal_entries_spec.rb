require 'rails_helper'

RSpec.describe "Web::JournalEntries", type: :request do
  let(:user) { create(:user) }
  let(:client) { create(:client, code: "test_client", name: "テスト社") }

  describe "GET /journal_entries" do
    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get journal_entries_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "client_code未指定の場合クライアント一覧にリダイレクトすること" do
        get journal_entries_path
        expect(response).to redirect_to(clients_path)
      end

      it "client_codeが空文字の場合クライアント一覧にリダイレクトすること" do
        get journal_entries_path(client_code: "")
        expect(response).to redirect_to(clients_path)
      end

      it "存在しないclient_codeの場合クライアント一覧にリダイレクトすること" do
        get journal_entries_path(client_code: "nonexistent")
        expect(response).to redirect_to(clients_path)
      end

      it "有効なclient_codeで200を返すこと" do
        get journal_entries_path(client_code: client.code)
        expect(response).to have_http_status(:ok)
      end

      it "ヘッダーにクライアント名が表示されること" do
        get journal_entries_path(client_code: client.code)
        expect(response.body).to include("テスト社")
        expect(response.body).to include("仕訳一覧")
      end

      it "21データカラムがCSV_HEADERSの順序で表示されること" do
        create(:journal_entry, client: client)
        get journal_entries_path(client_code: client.code)

        expect(response).to have_http_status(:ok)
        body = response.body

        expected_headers = [
          "No", "取引日",
          "借方勘定科目", "借方補助科目", "借方部門", "借方取引先", "借方税区分", "借方インボイス", "借方金額(円)",
          "貸方勘定科目", "貸方補助科目", "貸方部門", "貸方取引先", "貸方税区分", "貸方インボイス", "貸方金額(円)",
          "摘要", "タグ", "メモ", "カード利用者", "ステータス"
        ]
        expected_headers.each do |header|
          expect(body).to include(header), "ヘッダー「#{header}」が表示されていません"
        end
      end

      it "空のフィールドに「—」が表示されること" do
        create(:journal_entry, client: client, debit_sub_account: "", debit_department: "")
        get journal_entries_path(client_code: client.code)

        expect(response.body).to include("—")
      end

      describe "csv_export_status フィルタ" do
        let!(:unexported_entry) do
          create(:journal_entry, client: client, exported_at: nil,
                 debit_account: "未出力勘定", debit_amount: 1000, credit_amount: 1000)
        end
        let!(:exported_entry) do
          create(:journal_entry, client: client, exported_at: Time.current,
                 debit_account: "出力済勘定", debit_amount: 2000, credit_amount: 2000)
        end

        it "unexported指定で未出力のみ表示すること" do
          get journal_entries_path(client_code: client.code, csv_export_status: "unexported")
          expect(response.body).to include("未出力勘定")
          expect(response.body).not_to include("出力済勘定")
        end

        it "exported指定で出力済みのみ表示すること" do
          get journal_entries_path(client_code: client.code, csv_export_status: "exported")
          expect(response.body).to include("出力済勘定")
          expect(response.body).not_to include("未出力勘定")
        end

        it "未指定で両方表示すること" do
          get journal_entries_path(client_code: client.code)
          expect(response.body).to include("未出力勘定")
          expect(response.body).to include("出力済勘定")
        end

        it "不正値（typo等）は silent acceptance で全件表示すること" do
          get journal_entries_path(client_code: client.code, csv_export_status: "typo")
          expect(response.body).to include("未出力勘定")
          expect(response.body).to include("出力済勘定")
        end
      end
    end
  end

  describe "GET /journal_entries/:id" do
    let(:entry) { create(:journal_entry, client: client) }

    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get journal_entry_path(entry, client_code: client.code)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "200を返すこと" do
        get journal_entry_path(entry, client_code: client.code)
        expect(response).to have_http_status(:ok)
      end

      it "ヘッダーにクライアント名とパンくずが表示されること" do
        get journal_entry_path(entry, client_code: client.code)
        expect(response.body).to include("テスト社")
        expect(response.body).to include("仕訳一覧")
      end
    end
  end

  describe "GET /journal_entries/export" do
    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get export_journal_entries_path(client_code: client.code)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "従来形式CSVをエクスポートできること" do
        create(:journal_entry, client: client, debit_account: "旅費交通費", credit_account: "未払金",
               debit_amount: 5000, credit_amount: 5000)

        get export_journal_entries_path(client_code: client.code, format_type: "csv")

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/csv")
        expect(response.content_type).to include("utf-8")

        csv = CSV.parse(response.body.sub("\uFEFF", ""), headers: true)
        expect(csv.size).to eq(1)
      end

      it "弥生単一仕訳CSVをエクスポートできること" do
        create(:journal_entry, client: client, debit_account: "旅費交通費", credit_account: "未払金",
               debit_amount: 5000, credit_amount: 5000)

        get export_journal_entries_path(client_code: client.code, format_type: "yayoi_single")

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/csv")
        expect(response.content_type).to include("windows-31j")

        decoded = response.body.force_encoding("Windows-31J").encode("UTF-8")
        rows = CSV.parse(decoded)
        expect(rows.length).to eq(1)
        expect(rows[0].length).to eq(25)
        expect(rows[0][0]).to eq("2000")
      end

      it "不正なformat_typeで400を返すこと" do
        get export_journal_entries_path(client_code: client.code, format_type: "invalid")
        expect(response).to have_http_status(:bad_request)
      end

      it "エクスポート後に対象仕訳の exported_at がセットされること" do
        entry = create(:journal_entry, client: client, debit_amount: 1000, credit_amount: 1000)
        expect(entry.exported_at).to be_nil

        get export_journal_entries_path(client_code: client.code, format_type: "csv")

        expect(response).to have_http_status(:ok)
        expect(entry.reload.exported_at).to be_present
      end

      it "csv_export_status=unexported で未出力のみエクスポートし、マーキングされること" do
        unexported = create(:journal_entry, client: client, exported_at: nil,
                            debit_account: "未出力勘定", debit_amount: 1000, credit_amount: 1000)
        already_exported = create(:journal_entry, client: client, exported_at: 1.day.ago,
                                  debit_account: "既出力勘定", debit_amount: 2000, credit_amount: 2000)

        get export_journal_entries_path(client_code: client.code,
                                        csv_export_status: "unexported", format_type: "csv")

        csv = CSV.parse(response.body.sub("﻿", ""), headers: true)
        expect(csv.size).to eq(1)
        expect(csv.first["借方勘定科目"]).to eq("未出力勘定")
        expect(unexported.reload.exported_at).to be_present
        expect(already_exported.reload.exported_at).to be_within(1.minute).of(1.day.ago)
      end

      it "source_typeでフィルタしてエクスポートできること" do
        create(:journal_entry, :amex, client: client, debit_amount: 1000, credit_amount: 1000)
        create(:journal_entry, :bank, client: client, debit_amount: 2000, credit_amount: 2000)

        get export_journal_entries_path(client_code: client.code, source_type: "amex")

        csv = CSV.parse(response.body.sub("\uFEFF", ""), headers: true)
        expect(csv.size).to eq(1)
      end
    end
  end

  describe "GET /journal_entries/:id/edit" do
    let(:entry) { create(:journal_entry, client: client) }

    context "未認証の場合" do
      it "ログイン画面にリダイレクトすること" do
        get edit_journal_entry_path(entry, client_code: client.code)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "認証済みの場合" do
      before { sign_in user }

      it "200を返すこと" do
        get edit_journal_entry_path(entry, client_code: client.code)
        expect(response).to have_http_status(:ok)
      end

      it "ヘッダーにクライアント名が表示されること" do
        get edit_journal_entry_path(entry, client_code: client.code)
        expect(response.body).to include("テスト社")
      end
    end
  end
end
