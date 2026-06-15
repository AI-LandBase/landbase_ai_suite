# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_06_11_105306) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_masters", force: :cascade do |t|
    t.bigint "client_id", null: false, comment: "クライアント"
    t.string "source_type", comment: "入力元区別: amex / bank / invoice / receipt（nilは全ソース共通）"
    t.string "merchant_keyword", comment: "店舗名キーワード（マッチング用）"
    t.string "description_keyword", comment: "取引内容キーワード（マッチング用）"
    t.string "account_category", null: false, comment: "勘定科目カテゴリ"
    t.integer "confidence_score", default: 50, comment: "信頼度スコア（0-100）"
    t.date "last_used_date", comment: "最終使用日"
    t.integer "usage_count", default: 0, comment: "使用回数"
    t.boolean "auto_learned", default: false, comment: "自動学習フラグ"
    t.text "notes", default: "", comment: "備考"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "source_type"], name: "idx_account_masters_client_source"
    t.index ["client_id"], name: "index_account_masters_on_client_id"
    t.index ["merchant_keyword"], name: "idx_account_masters_merchant"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.string "name", null: false, comment: "トークン識別名（例: n8n, development）"
    t.string "token_digest", null: false, comment: "SHA256ハッシュ化トークン"
    t.datetime "last_used_at", comment: "最終使用日時"
    t.datetime "expires_at", comment: "有効期限（nilは無期限）"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "cleaning_manuals", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "property_name", null: false
    t.string "room_type", null: false
    t.jsonb "manual_data", default: {}, null: false
    t.string "status", default: "draft", null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "property_name"], name: "index_cleaning_manuals_on_client_id_and_property_name"
    t.index ["client_id"], name: "index_cleaning_manuals_on_client_id"
    t.index ["status"], name: "index_cleaning_manuals_on_status"
  end

  create_table "cleaning_session_attempts", force: :cascade do |t|
    t.bigint "cleaning_session_step_id", null: false
    t.integer "attempt_number", null: false
    t.string "result", null: false
    t.text "ai_feedback"
    t.datetime "judged_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cleaning_session_step_id", "attempt_number"], name: "idx_session_attempts_unique", unique: true
    t.index ["cleaning_session_step_id"], name: "index_cleaning_session_attempts_on_cleaning_session_step_id"
  end

  create_table "cleaning_session_steps", force: :cascade do |t|
    t.bigint "cleaning_session_id", null: false
    t.string "area_name", null: false
    t.integer "area_index", null: false
    t.integer "step_index", null: false
    t.string "task", null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts_count", default: 0, null: false
    t.datetime "passed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.text "checkpoint"
    t.integer "estimated_minutes"
    t.index ["cleaning_session_id", "area_index", "step_index"], name: "idx_session_steps_unique", unique: true
    t.index ["cleaning_session_id"], name: "index_cleaning_session_steps_on_cleaning_session_id"
  end

  create_table "cleaning_sessions", force: :cascade do |t|
    t.bigint "cleaning_manual_id", null: false
    t.bigint "client_id", null: false
    t.string "staff_name", null: false
    t.string "status", default: "in_progress", null: false
    t.datetime "started_at", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cleaning_manual_id", "status"], name: "index_cleaning_sessions_on_cleaning_manual_id_and_status"
    t.index ["cleaning_manual_id"], name: "index_cleaning_sessions_on_cleaning_manual_id"
    t.index ["client_id", "status"], name: "index_cleaning_sessions_on_client_id_and_status"
    t.index ["client_id"], name: "index_cleaning_sessions_on_client_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "code", null: false, comment: "クライアント識別子 (例: ikigai_stay)"
    t.string "name", null: false, comment: "クライアント名"
    t.string "industry", comment: "業種: restaurant / hotel / tour"
    t.jsonb "services", default: {}, comment: "サービス設定"
    t.string "status", default: "active", comment: "ステータス: active / trial / inactive"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "idx_clients_code", unique: true
    t.index ["services"], name: "idx_clients_services", using: :gin
  end

  create_table "journal_entries", force: :cascade do |t|
    t.bigint "client_id", null: false, comment: "クライアント"
    t.string "source_type", null: false, comment: "入力元区別: amex / bank / invoice / receipt"
    t.string "source_period", comment: "明細期間（例: 2026-01）"
    t.integer "transaction_no", comment: "取引番号"
    t.date "date", null: false, comment: "取引日"
    t.text "description", default: "", comment: "摘要"
    t.string "tag", default: "", comment: "タグ"
    t.text "memo", default: "", comment: "メモ"
    t.string "cardholder", default: "", comment: "カード利用者（Amex等の複数会員明細用）"
    t.string "status", default: "ok", comment: "確認状態: ok / review_required"
    t.bigint "statement_batch_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "exported_at", comment: "CSV出力日時（NULL=未出力）"
    t.index ["client_id", "source_type", "source_period", "transaction_no"], name: "idx_journal_entries_unique_transaction", unique: true
    t.index ["client_id"], name: "index_journal_entries_on_client_id"
    t.index ["date"], name: "idx_journal_entries_date"
    t.index ["exported_at"], name: "idx_journal_entries_csv_unexported", where: "(exported_at IS NULL)"
    t.index ["source_type", "source_period"], name: "idx_journal_entries_source"
    t.index ["statement_batch_id"], name: "index_journal_entries_on_statement_batch_id"
    t.index ["status"], name: "idx_journal_entries_review_required", where: "((status)::text = 'review_required'::text)"
  end

  create_table "line_followers", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "line_user_id", null: false, comment: "LINE user ID"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_line_followers_on_client_id"
    t.index ["line_user_id"], name: "index_line_followers_on_line_user_id", unique: true
  end

  create_table "journal_entry_lines", force: :cascade do |t|
    t.bigint "journal_entry_id", null: false, comment: "仕訳"
    t.string "side", null: false, comment: "借方/貸方: debit / credit"
    t.string "account", null: false, comment: "勘定科目"
    t.string "sub_account", default: "", comment: "補助科目"
    t.string "department", default: "", comment: "部門"
    t.string "partner", default: "", comment: "取引先"
    t.string "tax_category", default: "", comment: "税区分"
    t.string "invoice", default: "", comment: "インボイス番号"
    t.integer "amount", null: false, comment: "金額"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journal_entry_id", "side"], name: "idx_journal_entry_lines_entry_side"
    t.index ["journal_entry_id"], name: "index_journal_entry_lines_on_journal_entry_id"
  end

  create_table "statement_batches", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "source_type", default: "amex", null: false, comment: "入力元区別: amex / bank / invoice / receipt"
    t.string "status", default: "processing", null: false, comment: "処理状態: processing / completed / failed"
    t.text "error_message", comment: "エラーメッセージ"
    t.jsonb "summary", default: {}, comment: "処理結果サマリー"
    t.string "pdf_fingerprint", comment: "PDFファイルのSHA256ハッシュ（重複検知用）"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "pdf_fingerprint"], name: "idx_statement_batches_client_fingerprint"
    t.index ["client_id", "status"], name: "idx_statement_batches_client_status"
    t.index ["client_id"], name: "index_statement_batches_on_client_id"
    t.index ["status"], name: "index_statement_batches_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "account_masters", "clients"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cleaning_manuals", "clients"
  add_foreign_key "cleaning_session_attempts", "cleaning_session_steps"
  add_foreign_key "cleaning_session_steps", "cleaning_sessions"
  add_foreign_key "cleaning_sessions", "cleaning_manuals"
  add_foreign_key "cleaning_sessions", "clients"
  add_foreign_key "journal_entries", "clients"
  add_foreign_key "journal_entries", "statement_batches"
  add_foreign_key "journal_entry_lines", "journal_entries"
  add_foreign_key "line_followers", "clients"
  add_foreign_key "statement_batches", "clients"
end
