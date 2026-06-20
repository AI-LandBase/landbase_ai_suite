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

ActiveRecord::Schema[8.0].define(version: 2026_06_20_062736) do
  create_schema "n8n"

  # These are extensions that must be enabled in order to support this database
  enable_extension "n8n.uuid-ossp"
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

  create_table "audits", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.string "userid", limit: 26
    t.string "action", limit: 512
    t.string "extrainfo", limit: 1024
    t.string "ipaddress", limit: 64
    t.string "sessionid", limit: 26
    t.index ["userid"], name: "idx_audits_user_id"
  end

  create_table "bots", primary_key: "userid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "description", limit: 1024
    t.string "ownerid", limit: 190
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.bigint "lasticonupdate"
  end

  create_table "channelmemberhistory", primary_key: ["channelid", "userid", "jointime"], force: :cascade do |t|
    t.string "channelid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.bigint "jointime", null: false
    t.bigint "leavetime"
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
    t.string "industries", default: [], null: false, comment: "業種（複数選択可）: restaurant / hotel / tour", array: true
    t.index ["code"], name: "idx_clients_code", unique: true
    t.index ["services"], name: "idx_clients_services", using: :gin
  end

  create_table "clusterdiscovery", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "type", limit: 64
    t.string "clustername", limit: 64
    t.string "hostname", limit: 512
    t.integer "gossipport"
    t.integer "port"
    t.bigint "createat"
    t.bigint "lastpingat"
  end

  create_table "commands", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "token", limit: 26
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "creatorid", limit: 26
    t.string "teamid", limit: 26
    t.string "trigger", limit: 128
    t.string "method", limit: 1
    t.string "username", limit: 64
    t.string "iconurl", limit: 1024
    t.boolean "autocomplete"
    t.string "autocompletedesc", limit: 1024
    t.string "autocompletehint", limit: 1024
    t.string "displayname", limit: 64
    t.string "description", limit: 128
    t.string "url", limit: 1024
    t.string "pluginid", limit: 190
    t.index ["createat"], name: "idx_command_create_at"
    t.index ["deleteat"], name: "idx_command_delete_at"
    t.index ["teamid"], name: "idx_command_team_id"
    t.index ["updateat"], name: "idx_command_update_at"
  end

  create_table "commandwebhooks", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.string "commandid", limit: 26
    t.string "userid", limit: 26
    t.string "channelid", limit: 26
    t.string "rootid", limit: 26
    t.string "parentid", limit: 26
    t.integer "usecount"
    t.index ["createat"], name: "idx_command_webhook_create_at"
  end

  create_table "compliances", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.string "userid", limit: 26
    t.string "status", limit: 64
    t.integer "count"
    t.string "desc", limit: 512
    t.string "type", limit: 64
    t.bigint "startat"
    t.bigint "endat"
    t.string "keywords", limit: 512
    t.string "emails", limit: 1024
  end

  create_table "db_lock", id: { type: :string, limit: 64 }, force: :cascade do |t|
    t.bigint "expireat"
  end

  create_table "db_migrations", primary_key: "version", id: :bigint, default: nil, force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "emoji", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "creatorid", limit: 26
    t.string "name", limit: 64
    t.index ["createat"], name: "idx_emoji_create_at"
    t.index ["deleteat"], name: "idx_emoji_delete_at"
    t.index ["updateat"], name: "idx_emoji_update_at"
    t.unique_constraint ["name", "deleteat"], name: "emoji_name_deleteat_key"
  end

  create_table "groupchannels", primary_key: ["groupid", "channelid"], force: :cascade do |t|
    t.string "groupid", limit: 26, null: false
    t.boolean "autoadd"
    t.boolean "schemeadmin"
    t.bigint "createat"
    t.bigint "deleteat"
    t.bigint "updateat"
    t.string "channelid", limit: 26, null: false
    t.index ["channelid"], name: "idx_groupchannels_channelid"
  end

  create_table "groupmembers", primary_key: ["groupid", "userid"], force: :cascade do |t|
    t.string "groupid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.bigint "createat"
    t.bigint "deleteat"
    t.index ["createat"], name: "idx_groupmembers_create_at"
  end

  create_table "groupteams", primary_key: ["groupid", "teamid"], force: :cascade do |t|
    t.string "groupid", limit: 26, null: false
    t.boolean "autoadd"
    t.boolean "schemeadmin"
    t.bigint "createat"
    t.bigint "deleteat"
    t.bigint "updateat"
    t.string "teamid", limit: 26, null: false
    t.index ["schemeadmin"], name: "idx_groupteams_schemeadmin"
    t.index ["teamid"], name: "idx_groupteams_teamid"
  end

  create_table "incomingwebhooks", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "userid", limit: 26
    t.string "channelid", limit: 26
    t.string "teamid", limit: 26
    t.string "displayname", limit: 64
    t.string "description", limit: 500
    t.string "username", limit: 255
    t.string "iconurl", limit: 1024
    t.boolean "channellocked"
    t.index ["createat"], name: "idx_incoming_webhook_create_at"
    t.index ["deleteat"], name: "idx_incoming_webhook_delete_at"
    t.index ["teamid"], name: "idx_incoming_webhook_team_id"
    t.index ["updateat"], name: "idx_incoming_webhook_update_at"
    t.index ["userid"], name: "idx_incoming_webhook_user_id"
  end

  create_table "jobs", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "type", limit: 32
    t.bigint "priority"
    t.bigint "createat"
    t.bigint "startat"
    t.bigint "lastactivityat"
    t.string "status", limit: 32
    t.bigint "progress"
    t.string "data", limit: 1024
    t.index ["type"], name: "idx_jobs_type"
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
    t.string "card_last_four"
    t.index ["client_id", "source_type", "source_period", "transaction_no"], name: "idx_journal_entries_unique_transaction", unique: true
    t.index ["client_id"], name: "index_journal_entries_on_client_id"
    t.index ["date"], name: "idx_journal_entries_date"
    t.index ["exported_at"], name: "idx_journal_entries_csv_unexported", where: "(exported_at IS NULL)"
    t.index ["source_type", "source_period"], name: "idx_journal_entries_source"
    t.index ["statement_batch_id"], name: "index_journal_entries_on_statement_batch_id"
    t.index ["status"], name: "idx_journal_entries_review_required", where: "((status)::text = 'review_required'::text)"
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

  create_table "journal_entry_revisions", force: :cascade do |t|
    t.bigint "journal_entry_id", null: false
    t.bigint "user_id"
    t.jsonb "changes_diff", default: {}, null: false
    t.jsonb "snapshot", default: {}, null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journal_entry_id", "created_at"], name: "idx_on_journal_entry_id_created_at_9c0965e380"
    t.index ["journal_entry_id"], name: "index_journal_entry_revisions_on_journal_entry_id"
    t.index ["user_id"], name: "index_journal_entry_revisions_on_user_id"
  end

  create_table "licenses", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.string "bytes", limit: 10000
  end

  create_table "line_followers", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "line_user_id", null: false, comment: "LINE user ID"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_line_followers_on_client_id"
    t.index ["line_user_id"], name: "index_line_followers_on_line_user_id", unique: true
  end

  create_table "linkmetadata", primary_key: "hash", id: :bigint, default: nil, force: :cascade do |t|
    t.string "url", limit: 2048
    t.bigint "timestamp"
    t.string "type", limit: 16
    t.string "data", limit: 4096
    t.index ["url", "timestamp"], name: "idx_link_metadata_url_timestamp"
  end

  create_table "oauthaccessdata", primary_key: "token", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "refreshtoken", limit: 26
    t.string "redirecturi", limit: 256
    t.string "clientid", limit: 26
    t.string "userid", limit: 26
    t.bigint "expiresat"
    t.string "scope", limit: 128
    t.index ["refreshtoken"], name: "idx_oauthaccessdata_refresh_token"
    t.index ["userid"], name: "idx_oauthaccessdata_user_id"
    t.unique_constraint ["clientid", "userid"], name: "oauthaccessdata_clientid_userid_key"
  end

  create_table "oauthauthdata", primary_key: "code", id: { type: :string, limit: 128 }, force: :cascade do |t|
    t.string "clientid", limit: 26
    t.string "userid", limit: 26
    t.integer "expiresin"
    t.bigint "createat"
    t.string "redirecturi", limit: 256
    t.string "state", limit: 1024
    t.string "scope", limit: 128
  end

  create_table "outgoingwebhooks", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "token", limit: 26
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "creatorid", limit: 26
    t.string "channelid", limit: 26
    t.string "teamid", limit: 26
    t.string "triggerwords", limit: 1024
    t.string "callbackurls", limit: 1024
    t.string "displayname", limit: 64
    t.string "contenttype", limit: 128
    t.integer "triggerwhen"
    t.string "username", limit: 64
    t.string "iconurl", limit: 1024
    t.string "description", limit: 500
    t.index ["createat"], name: "idx_outgoing_webhook_create_at"
    t.index ["deleteat"], name: "idx_outgoing_webhook_delete_at"
    t.index ["teamid"], name: "idx_outgoing_webhook_team_id"
    t.index ["updateat"], name: "idx_outgoing_webhook_update_at"
  end

  create_table "payment_cards", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.string "last_four", null: false
    t.string "card_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "last_four"], name: "index_payment_cards_on_client_id_and_last_four", unique: true
    t.index ["client_id"], name: "index_payment_cards_on_client_id"
  end

  create_table "pluginkeyvaluestore", primary_key: ["pluginid", "pkey"], force: :cascade do |t|
    t.string "pluginid", limit: 190, null: false
    t.string "pkey", limit: 50, null: false
    t.binary "pvalue"
    t.bigint "expireat"
  end

  create_table "posts", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "userid", limit: 26
    t.string "channelid", limit: 26
    t.string "rootid", limit: 26
    t.string "parentid", limit: 26
    t.string "originalid", limit: 26
    t.string "message", limit: 65535
    t.string "type", limit: 26
    t.string "props", limit: 8000
    t.string "hashtags", limit: 1000
    t.string "filenames", limit: 4000
    t.string "fileids", limit: 300
    t.boolean "hasreactions"
    t.bigint "editat"
    t.boolean "ispinned"
    t.string "remoteid", limit: 26
    t.index "to_tsvector('english'::regconfig, (hashtags)::text)", name: "idx_posts_hashtags_txt", using: :gin
    t.index "to_tsvector('english'::regconfig, (message)::text)", name: "idx_posts_message_txt", using: :gin
    t.index ["channelid", "deleteat", "createat"], name: "idx_posts_channel_id_delete_at_create_at"
    t.index ["channelid", "updateat"], name: "idx_posts_channel_id_update_at"
    t.index ["createat"], name: "idx_posts_create_at"
    t.index ["deleteat"], name: "idx_posts_delete_at"
    t.index ["ispinned"], name: "idx_posts_is_pinned"
    t.index ["rootid"], name: "idx_posts_root_id"
    t.index ["updateat"], name: "idx_posts_update_at"
    t.index ["userid"], name: "idx_posts_user_id"
  end

  create_table "preferences", primary_key: ["userid", "category", "name"], force: :cascade do |t|
    t.string "userid", limit: 26, null: false
    t.string "category", limit: 32, null: false
    t.string "name", limit: 32, null: false
    t.string "value", limit: 2000
    t.index ["category"], name: "idx_preferences_category"
    t.index ["name"], name: "idx_preferences_name"
  end

  create_table "productnoticeviewstate", primary_key: ["userid", "noticeid"], force: :cascade do |t|
    t.string "userid", limit: 26, null: false
    t.string "noticeid", limit: 26, null: false
    t.integer "viewed"
    t.bigint "timestamp"
    t.index ["noticeid"], name: "idx_notice_views_notice_id"
    t.index ["timestamp"], name: "idx_notice_views_timestamp"
  end

  create_table "reactions", primary_key: ["postid", "userid", "emojiname"], force: :cascade do |t|
    t.string "userid", limit: 26, null: false
    t.string "postid", limit: 26, null: false
    t.string "emojiname", limit: 64, null: false
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "remoteid", limit: 26
  end

  create_table "remoteclusters", primary_key: ["remoteid", "name"], force: :cascade do |t|
    t.string "remoteid", limit: 26, null: false
    t.string "remoteteamid", limit: 26
    t.string "name", limit: 64, null: false
    t.string "displayname", limit: 64
    t.string "siteurl", limit: 512
    t.bigint "createat"
    t.bigint "lastpingat"
    t.string "token", limit: 26
    t.string "remotetoken", limit: 26
    t.string "topics", limit: 512
    t.string "creatorid", limit: 26
    t.index ["siteurl", "remoteteamid"], name: "remote_clusters_site_url_unique", unique: true
  end

  create_table "roles", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "name", limit: 64
    t.string "displayname", limit: 128
    t.string "description", limit: 1024
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.text "permissions"
    t.boolean "schememanaged"
    t.boolean "builtin"

    t.unique_constraint ["name"], name: "roles_name_key"
  end

  create_table "schemes", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "name", limit: 64
    t.string "displayname", limit: 128
    t.string "description", limit: 1024
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "scope", limit: 32
    t.string "defaultteamadminrole", limit: 64
    t.string "defaultteamuserrole", limit: 64
    t.string "defaultchanneladminrole", limit: 64
    t.string "defaultchanneluserrole", limit: 64
    t.string "defaultteamguestrole", limit: 64
    t.string "defaultchannelguestrole", limit: 64
    t.index ["defaultchanneladminrole"], name: "idx_schemes_channel_admin_role"
    t.index ["defaultchannelguestrole"], name: "idx_schemes_channel_guest_role"
    t.index ["defaultchanneluserrole"], name: "idx_schemes_channel_user_role"
    t.unique_constraint ["name"], name: "schemes_name_key"
  end

  create_table "sessions", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "token", limit: 26
    t.bigint "createat"
    t.bigint "expiresat"
    t.bigint "lastactivityat"
    t.string "userid", limit: 26
    t.string "deviceid", limit: 512
    t.string "roles", limit: 64
    t.boolean "isoauth"
    t.string "props", limit: 1000
    t.boolean "expirednotify"
    t.index ["createat"], name: "idx_sessions_create_at"
    t.index ["expiresat"], name: "idx_sessions_expires_at"
    t.index ["lastactivityat"], name: "idx_sessions_last_activity_at"
    t.index ["token"], name: "idx_sessions_token"
    t.index ["userid"], name: "idx_sessions_user_id"
  end

  create_table "sharedchannelattachments", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "fileid", limit: 26
    t.string "remoteid", limit: 26
    t.bigint "createat"
    t.bigint "lastsyncat"

    t.unique_constraint ["fileid", "remoteid"], name: "sharedchannelattachments_fileid_remoteid_key"
  end

  create_table "sharedchannelremotes", primary_key: ["id", "channelid"], force: :cascade do |t|
    t.string "id", limit: 26, null: false
    t.string "channelid", limit: 26, null: false
    t.string "creatorid", limit: 26
    t.bigint "createat"
    t.bigint "updateat"
    t.boolean "isinviteaccepted"
    t.boolean "isinviteconfirmed"
    t.string "remoteid", limit: 26
    t.bigint "lastpostupdateat"
    t.string "lastpostid", limit: 26

    t.unique_constraint ["channelid", "remoteid"], name: "sharedchannelremotes_channelid_remoteid_key"
  end

  create_table "sharedchannels", primary_key: "channelid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "teamid", limit: 26
    t.boolean "home"
    t.boolean "readonly"
    t.string "sharename", limit: 64
    t.string "sharedisplayname", limit: 64
    t.string "sharepurpose", limit: 250
    t.string "shareheader", limit: 1024
    t.string "creatorid", limit: 26
    t.bigint "createat"
    t.bigint "updateat"
    t.string "remoteid", limit: 26

    t.unique_constraint ["sharename", "teamid"], name: "sharedchannels_sharename_teamid_key"
  end

  create_table "sharedchannelusers", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "userid", limit: 26
    t.string "remoteid", limit: 26
    t.bigint "createat"
    t.bigint "lastsyncat"
    t.string "channelid", limit: 26
    t.index ["remoteid"], name: "idx_sharedchannelusers_remote_id"
    t.unique_constraint ["userid", "channelid", "remoteid"], name: "sharedchannelusers_userid_channelid_remoteid_key"
  end

  create_table "sidebarcategories", id: { type: :string, limit: 128 }, force: :cascade do |t|
    t.string "userid", limit: 26
    t.string "teamid", limit: 26
    t.bigint "sortorder"
    t.string "sorting", limit: 64
    t.string "type", limit: 64
    t.string "displayname", limit: 64
    t.boolean "muted"
    t.boolean "collapsed"
  end

  create_table "sidebarchannels", primary_key: ["channelid", "userid", "categoryid"], force: :cascade do |t|
    t.string "channelid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.string "categoryid", limit: 128, null: false
    t.bigint "sortorder"
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

  create_table "status", primary_key: "userid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "status", limit: 32
    t.boolean "manual"
    t.bigint "lastactivityat"
    t.bigint "dndendtime"
    t.string "prevstatus", limit: 32
    t.index ["status"], name: "idx_status_status"
  end

  create_table "systems", primary_key: "name", id: { type: :string, limit: 64 }, force: :cascade do |t|
    t.string "value", limit: 1024
  end

  create_table "teammembers", primary_key: ["teamid", "userid"], force: :cascade do |t|
    t.string "teamid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.string "roles", limit: 64
    t.bigint "deleteat"
    t.boolean "schemeuser"
    t.boolean "schemeadmin"
    t.boolean "schemeguest"
    t.index ["deleteat"], name: "idx_teammembers_delete_at"
    t.index ["userid"], name: "idx_teammembers_user_id"
  end

  create_table "teams", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "displayname", limit: 64
    t.string "name", limit: 64
    t.string "description", limit: 255
    t.string "email", limit: 128
    t.string "type", limit: 255
    t.string "companyname", limit: 64
    t.string "alloweddomains", limit: 1000
    t.string "inviteid", limit: 32
    t.string "schemeid", limit: 26
    t.boolean "allowopeninvite"
    t.bigint "lastteamiconupdate"
    t.boolean "groupconstrained"
    t.index ["createat"], name: "idx_teams_create_at"
    t.index ["deleteat"], name: "idx_teams_delete_at"
    t.index ["inviteid"], name: "idx_teams_invite_id"
    t.index ["schemeid"], name: "idx_teams_scheme_id"
    t.index ["updateat"], name: "idx_teams_update_at"
    t.unique_constraint ["name"], name: "teams_name_key"
  end

  create_table "termsofservice", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.string "userid", limit: 26
    t.string "text", limit: 65535
  end

  create_table "threadmemberships", primary_key: ["postid", "userid"], force: :cascade do |t|
    t.string "postid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.boolean "following"
    t.bigint "lastviewed"
    t.bigint "lastupdated"
    t.bigint "unreadmentions"
    t.index ["lastupdated"], name: "idx_thread_memberships_last_update_at"
    t.index ["lastviewed"], name: "idx_thread_memberships_last_view_at"
    t.index ["userid"], name: "idx_thread_memberships_user_id"
  end

  create_table "threads", primary_key: "postid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "replycount"
    t.bigint "lastreplyat"
    t.text "participants"
    t.string "channelid", limit: 26
    t.index ["channelid"], name: "idx_threads_channel_id"
  end

  create_table "tokens", primary_key: "token", id: { type: :string, limit: 64 }, force: :cascade do |t|
    t.bigint "createat"
    t.string "type", limit: 64
    t.string "extra", limit: 2048
  end

  create_table "uploadsessions", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "type", limit: 32
    t.bigint "createat"
    t.string "userid", limit: 26
    t.string "channelid", limit: 26
    t.string "filename", limit: 256
    t.string "path", limit: 512
    t.bigint "filesize"
    t.bigint "fileoffset"
    t.string "remoteid", limit: 26
    t.string "reqfileid", limit: 26
    t.index ["createat"], name: "idx_uploadsessions_create_at"
    t.index ["type"], name: "idx_uploadsessions_type"
    t.index ["userid"], name: "idx_uploadsessions_user_id"
  end

  create_table "useraccesstokens", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "token", limit: 26
    t.string "userid", limit: 26
    t.string "description", limit: 512
    t.boolean "isactive"
    t.index ["userid"], name: "idx_user_access_tokens_user_id"
    t.unique_constraint ["token"], name: "useraccesstokens_token_key"
  end

  create_table "usergroups", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "name", limit: 64
    t.string "displayname", limit: 128
    t.string "description", limit: 1024
    t.string "source", limit: 64
    t.string "remoteid", limit: 48
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.boolean "allowreference"
    t.index ["deleteat"], name: "idx_usergroups_delete_at"
    t.index ["remoteid"], name: "idx_usergroups_remote_id"
    t.unique_constraint ["name"], name: "usergroups_name_key"
    t.unique_constraint ["source", "remoteid"], name: "usergroups_source_remoteid_key"
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

  create_table "usertermsofservice", primary_key: "userid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "termsofserviceid", limit: 26
    t.bigint "createat"
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
  add_foreign_key "journal_entry_revisions", "journal_entries"
  add_foreign_key "journal_entry_revisions", "users", on_delete: :nullify
  add_foreign_key "line_followers", "clients"
  add_foreign_key "payment_cards", "clients"
  add_foreign_key "statement_batches", "clients"
end
