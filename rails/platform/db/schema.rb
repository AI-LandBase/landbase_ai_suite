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

ActiveRecord::Schema[8.0].define(version: 2026_03_26_000000) do
  create_schema "n8n"

  # These are extensions that must be enabled in order to support this database
  enable_extension "n8n.uuid-ossp"
  enable_extension "pg_catalog.plpgsql"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "channel_bookmark_type", ["link", "file"]
  create_enum "channel_type", ["P", "G", "O", "D"]
  create_enum "outgoingoauthconnections_granttype", ["client_credentials", "password"]
  create_enum "team_type", ["I", "O"]
  create_enum "upload_session_type", ["attachment", "import"]

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

  create_table "calls", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "channelid", limit: 26
    t.bigint "startat"
    t.bigint "endat"
    t.bigint "createat"
    t.bigint "deleteat"
    t.string "title", limit: 256
    t.string "postid", limit: 26
    t.string "threadid", limit: 26
    t.string "ownerid", limit: 26
    t.jsonb "participants", null: false
    t.jsonb "stats", null: false
    t.jsonb "props", null: false
    t.index ["channelid"], name: "idx_calls_channel_id"
    t.index ["endat"], name: "idx_calls_end_at"
  end

  create_table "calls_channels", primary_key: "channelid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.boolean "enabled"
    t.jsonb "props", null: false
  end

  create_table "calls_jobs", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "callid", limit: 26
    t.string "type", limit: 64
    t.string "creatorid", limit: 26
    t.bigint "initat"
    t.bigint "startat"
    t.bigint "endat"
    t.jsonb "props", null: false
    t.index ["callid"], name: "idx_calls_jobs_call_id"
  end

  create_table "calls_sessions", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "callid", limit: 26
    t.string "userid", limit: 26
    t.bigint "joinat"
    t.boolean "unmuted"
    t.bigint "raisedhand"
    t.index ["callid"], name: "idx_calls_sessions_call_id"
  end

  create_table "channelbookmarks", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "ownerid", limit: 26, null: false
    t.string "channelid", limit: 26, null: false
    t.string "fileinfoid", limit: 26
    t.bigint "createat", default: 0
    t.bigint "updateat", default: 0
    t.bigint "deleteat", default: 0
    t.text "displayname", default: ""
    t.integer "sortorder", default: 0
    t.text "linkurl"
    t.text "imageurl"
    t.string "emoji", limit: 64
    t.enum "type", default: "link", enum_type: "channel_bookmark_type"
    t.string "originalid", limit: 26
    t.string "parentid", limit: 26
    t.index ["channelid"], name: "idx_channelbookmarks_channelid"
    t.index ["deleteat"], name: "idx_channelbookmarks_delete_at"
    t.index ["updateat"], name: "idx_channelbookmarks_update_at"
  end

  create_table "channelmemberhistory", primary_key: ["channelid", "userid", "jointime"], force: :cascade do |t|
    t.string "channelid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.bigint "jointime", null: false
    t.bigint "leavetime"
  end

  create_table "channelmembers", primary_key: ["channelid", "userid"], force: :cascade do |t|
    t.string "channelid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.string "roles", limit: 256
    t.bigint "lastviewedat"
    t.bigint "msgcount"
    t.bigint "mentioncount"
    t.jsonb "notifyprops"
    t.bigint "lastupdateat"
    t.boolean "schemeuser"
    t.boolean "schemeadmin"
    t.boolean "schemeguest"
    t.bigint "mentioncountroot"
    t.bigint "msgcountroot"
    t.bigint "urgentmentioncount"
    t.index ["channelid", "schemeguest", "userid"], name: "idx_channelmembers_channel_id_scheme_guest_user_id"
    t.index ["userid", "channelid", "lastviewedat"], name: "idx_channelmembers_user_id_channel_id_last_viewed_at"
  end

  create_table "channels", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "teamid", limit: 26
    t.enum "type", enum_type: "channel_type"
    t.string "displayname", limit: 64
    t.string "name", limit: 64
    t.string "header", limit: 1024
    t.string "purpose", limit: 250
    t.bigint "lastpostat"
    t.bigint "totalmsgcount"
    t.bigint "extraupdateat"
    t.string "creatorid", limit: 26
    t.string "schemeid", limit: 26
    t.boolean "groupconstrained"
    t.boolean "shared"
    t.bigint "totalmsgcountroot"
    t.bigint "lastrootpostat", default: 0
    t.index "lower((displayname)::text)", name: "idx_channels_displayname_lower"
    t.index "lower((name)::text)", name: "idx_channels_name_lower"
    t.index "to_tsvector('english'::regconfig, (((((name)::text || ' '::text) || (displayname)::text) || ' '::text) || (purpose)::text))", name: "idx_channel_search_txt", using: :gin
    t.index ["createat"], name: "idx_channels_create_at"
    t.index ["deleteat"], name: "idx_channels_delete_at"
    t.index ["schemeid"], name: "idx_channels_scheme_id"
    t.index ["teamid", "displayname"], name: "idx_channels_team_id_display_name"
    t.index ["teamid", "type"], name: "idx_channels_team_id_type"
    t.index ["updateat"], name: "idx_channels_update_at"
    t.unique_constraint ["name", "teamid"], name: "channels_name_teamid_key"
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

  create_table "clients", force: :cascade do |t|
    t.string "code", null: false, comment: "クライアント識別子 (例: ikigai_stay)"
    t.string "name", null: false, comment: "クライアント名"
    t.string "industry", comment: "業種: restaurant / hotel / tour"
    t.jsonb "services", default: {}, comment: "サービス設定"
    t.string "status", default: "active", comment: "ステータス: active / trial / inactive"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "company_name", comment: "自社名キーワード（例: ウェブラボ）。InvoiceProcessorで発行者/請求先判定に使用"
    t.string "line_user_id"
    t.index ["code"], name: "idx_clients_code", unique: true
    t.index ["line_user_id"], name: "index_clients_on_line_user_id", unique: true
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

  create_table "db_migrations_calls", primary_key: "version", id: :bigint, default: nil, force: :cascade do |t|
    t.string "name", null: false
  end

  create_table "desktoptokens", primary_key: "token", id: { type: :string, limit: 64 }, force: :cascade do |t|
    t.bigint "createat", null: false
    t.string "userid", limit: 26, null: false
    t.index ["token", "createat"], name: "idx_desktoptokens_token_createat"
  end

  create_table "drafts", primary_key: ["userid", "channelid", "rootid"], force: :cascade do |t|
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "userid", limit: 26, null: false
    t.string "channelid", limit: 26, null: false
    t.string "rootid", limit: 26, default: "", null: false
    t.string "message", limit: 65535
    t.string "props", limit: 8000
    t.string "fileids", limit: 300
    t.text "priority"
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

  create_table "fileinfo", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "creatorid", limit: 26
    t.string "postid", limit: 26
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "path", limit: 512
    t.string "thumbnailpath", limit: 512
    t.string "previewpath", limit: 512
    t.string "name", limit: 256
    t.string "extension", limit: 64
    t.bigint "size"
    t.string "mimetype", limit: 256
    t.integer "width"
    t.integer "height"
    t.boolean "haspreviewimage"
    t.binary "minipreview"
    t.text "content"
    t.string "remoteid", limit: 26
    t.boolean "archived", default: false, null: false
    t.string "channelid", limit: 26
    t.index "to_tsvector('english'::regconfig, (name)::text)", name: "idx_fileinfo_name_txt", using: :gin
    t.index "to_tsvector('english'::regconfig, content)", name: "idx_fileinfo_content_txt", using: :gin
    t.index "to_tsvector('english'::regconfig, translate((name)::text, '.,-'::text, '   '::text))", name: "idx_fileinfo_name_splitted", using: :gin
    t.index ["channelid", "createat"], name: "idx_fileinfo_channel_id_create_at"
    t.index ["createat"], name: "idx_fileinfo_create_at"
    t.index ["deleteat"], name: "idx_fileinfo_delete_at"
    t.index ["extension"], name: "idx_fileinfo_extension_at"
    t.index ["postid"], name: "idx_fileinfo_postid_at"
    t.index ["updateat"], name: "idx_fileinfo_update_at"
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
    t.index ["schemeadmin"], name: "idx_groupchannels_schemeadmin"
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

  create_table "ir_category", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "name", limit: 512, null: false
    t.string "teamid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.boolean "collapsed", default: false
    t.bigint "createat", null: false
    t.bigint "updateat", default: 0, null: false
    t.bigint "deleteat", default: 0, null: false
    t.index ["teamid", "userid"], name: "ir_category_teamid_userid"
  end

  create_table "ir_category_item", primary_key: ["categoryid", "itemid", "type"], force: :cascade do |t|
    t.string "type", limit: 1, null: false
    t.string "categoryid", limit: 26, null: false
    t.string "itemid", limit: 26, null: false
    t.index ["categoryid"], name: "ir_category_item_categoryid"
  end

  create_table "ir_channelaction", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "channelid", limit: 26
    t.boolean "enabled", default: false
    t.bigint "deleteat", default: 0, null: false
    t.string "actiontype", limit: 65535, null: false
    t.string "triggertype", limit: 65535, null: false
    t.json "payload", null: false
    t.index ["channelid"], name: "ir_channelaction_channelid"
  end

  create_table "ir_incident", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "name", limit: 1024, null: false
    t.string "description", limit: 4096, null: false
    t.boolean "isactive", null: false
    t.string "commanderuserid", limit: 26, null: false
    t.string "teamid", limit: 26, null: false
    t.string "channelid", limit: 26, null: false
    t.bigint "createat", null: false
    t.bigint "endat", default: 0, null: false
    t.bigint "deleteat", default: 0, null: false
    t.bigint "activestage", null: false
    t.string "postid", limit: 26, default: "", null: false
    t.string "playbookid", limit: 26, default: "", null: false
    t.json "checklistsjson", null: false
    t.string "activestagetitle", limit: 1024, default: ""
    t.string "reminderpostid", limit: 26
    t.string "broadcastchannelid", limit: 26, default: ""
    t.bigint "previousreminder", default: 0, null: false
    t.string "remindermessagetemplate", limit: 65535, default: ""
    t.string "currentstatus", limit: 1024, default: "Active", null: false
    t.string "reporteruserid", limit: 26, default: "", null: false
    t.string "concatenatedinviteduserids", limit: 65535, default: ""
    t.string "defaultcommanderid", limit: 26, default: ""
    t.string "announcementchannelid", limit: 26, default: ""
    t.string "concatenatedwebhookoncreationurls", limit: 65535, default: ""
    t.string "concatenatedinvitedgroupids", limit: 65535, default: ""
    t.string "retrospective", limit: 65535, default: ""
    t.string "messageonjoin", limit: 65535, default: ""
    t.bigint "retrospectivepublishedat", default: 0, null: false
    t.bigint "retrospectivereminderintervalseconds", default: 0, null: false
    t.boolean "retrospectivewascanceled", default: false
    t.string "concatenatedwebhookonstatusupdateurls", limit: 65535, default: ""
    t.bigint "laststatusupdateat", default: 0
    t.boolean "exportchannelonfinishedenabled", default: false, null: false
    t.boolean "categorizechannelenabled", default: false
    t.string "categoryname", limit: 65535, default: ""
    t.string "concatenatedbroadcastchannelids", limit: 65535
    t.string "channelidtorootid", limit: 65535, default: ""
    t.bigint "remindertimerdefaultseconds", default: 0, null: false
    t.boolean "statusupdateenabled", default: true
    t.boolean "retrospectiveenabled", default: true
    t.boolean "statusupdatebroadcastchannelsenabled", default: false
    t.boolean "statusupdatebroadcastwebhooksenabled", default: false
    t.bigint "summarymodifiedat", default: 0, null: false
    t.boolean "createchannelmemberonnewparticipant", default: true
    t.boolean "removechannelmemberonremovedparticipant", default: true
    t.string "runtype", limit: 32, default: "playbook"
    t.index ["channelid"], name: "ir_incident_channelid"
    t.index ["teamid", "commanderuserid"], name: "ir_incident_teamid_commanderuserid"
    t.index ["teamid"], name: "ir_incident_teamid"
  end

  create_table "ir_metric", primary_key: ["incidentid", "metricconfigid"], force: :cascade do |t|
    t.string "incidentid", limit: 26, null: false
    t.string "metricconfigid", limit: 26, null: false
    t.bigint "value"
    t.boolean "published", null: false
    t.index ["incidentid"], name: "ir_metric_incidentid"
    t.index ["metricconfigid"], name: "ir_metric_metricconfigid"
  end

  create_table "ir_metricconfig", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "playbookid", limit: 26, null: false
    t.string "title", limit: 512, null: false
    t.string "description", limit: 4096, null: false
    t.string "type", limit: 32, null: false
    t.bigint "target"
    t.integer "ordering", limit: 2, default: 0, null: false
    t.bigint "deleteat", default: 0, null: false
    t.index ["playbookid"], name: "ir_metricconfig_playbookid"
  end

  create_table "ir_playbook", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "title", limit: 1024, null: false
    t.string "description", limit: 4096, null: false
    t.string "teamid", limit: 26, null: false
    t.boolean "createpublicincident", null: false
    t.bigint "createat", null: false
    t.bigint "deleteat", default: 0, null: false
    t.json "checklistsjson", null: false
    t.bigint "numstages", default: 0, null: false
    t.bigint "numsteps", default: 0, null: false
    t.string "broadcastchannelid", limit: 26, default: ""
    t.string "remindermessagetemplate", limit: 65535, default: ""
    t.bigint "remindertimerdefaultseconds", default: 0, null: false
    t.string "concatenatedinviteduserids", limit: 65535, default: ""
    t.boolean "inviteusersenabled", default: false
    t.string "defaultcommanderid", limit: 26, default: ""
    t.boolean "defaultcommanderenabled", default: false
    t.string "announcementchannelid", limit: 26, default: ""
    t.boolean "announcementchannelenabled", default: false
    t.string "concatenatedwebhookoncreationurls", limit: 65535, default: ""
    t.boolean "webhookoncreationenabled", default: false
    t.string "concatenatedinvitedgroupids", limit: 65535, default: ""
    t.string "messageonjoin", limit: 65535, default: ""
    t.boolean "messageonjoinenabled", default: false
    t.bigint "retrospectivereminderintervalseconds", default: 0, null: false
    t.string "retrospectivetemplate", limit: 65535
    t.string "concatenatedwebhookonstatusupdateurls", limit: 65535, default: ""
    t.boolean "webhookonstatusupdateenabled", default: false
    t.string "concatenatedsignalanykeywords", limit: 65535, default: ""
    t.boolean "signalanykeywordsenabled", default: false
    t.bigint "updateat", default: 0, null: false
    t.boolean "exportchannelonfinishedenabled", default: false, null: false
    t.boolean "categorizechannelenabled", default: false
    t.string "categoryname", limit: 65535, default: ""
    t.string "concatenatedbroadcastchannelids", limit: 65535
    t.boolean "broadcastenabled", default: false
    t.string "runsummarytemplate", limit: 65535, default: ""
    t.string "channelnametemplate", limit: 65535, default: ""
    t.boolean "statusupdateenabled", default: true
    t.boolean "retrospectiveenabled", default: true
    t.boolean "public", default: false
    t.boolean "runsummarytemplateenabled", default: true
    t.boolean "createchannelmemberonnewparticipant", default: true
    t.boolean "removechannelmemberonremovedparticipant", default: true
    t.string "channelid", limit: 26, default: ""
    t.string "channelmode", limit: 32, default: "create_new_channel"
    t.index ["teamid"], name: "ir_playbook_teamid"
    t.index ["updateat"], name: "ir_playbook_updateat"
  end

  create_table "ir_playbookautofollow", primary_key: ["playbookid", "userid"], force: :cascade do |t|
    t.string "playbookid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
  end

  create_table "ir_playbookmember", primary_key: ["memberid", "playbookid"], force: :cascade do |t|
    t.string "playbookid", limit: 26, null: false
    t.string "memberid", limit: 26, null: false
    t.string "roles", limit: 65535
    t.index ["memberid"], name: "ir_playbookmember_memberid"
    t.index ["playbookid"], name: "ir_playbookmember_playbookid"
    t.unique_constraint ["playbookid", "memberid"], name: "ir_playbookmember_playbookid_memberid_key"
  end

  create_table "ir_run_participants", primary_key: ["incidentid", "userid"], force: :cascade do |t|
    t.string "userid", limit: 26, null: false
    t.string "incidentid", limit: 26, null: false
    t.boolean "isfollower", default: false, null: false
    t.boolean "isparticipant", default: false
    t.index ["incidentid"], name: "ir_run_participants_incidentid"
    t.index ["userid"], name: "ir_run_participants_userid"
  end

  create_table "ir_statusposts", primary_key: ["incidentid", "postid"], force: :cascade do |t|
    t.string "incidentid", limit: 26, null: false
    t.string "postid", limit: 26, null: false
    t.index ["incidentid"], name: "ir_statusposts_incidentid"
    t.index ["postid"], name: "ir_statusposts_postid"
    t.unique_constraint ["incidentid", "postid"], name: "ir_statusposts_incidentid_postid_key"
  end

  create_table "ir_system", primary_key: "skey", id: { type: :string, limit: 64 }, force: :cascade do |t|
    t.string "svalue", limit: 1024
  end

  create_table "ir_timelineevent", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "incidentid", limit: 26, null: false
    t.bigint "createat", null: false
    t.bigint "deleteat", default: 0, null: false
    t.bigint "eventat", null: false
    t.string "eventtype", limit: 32, default: "", null: false
    t.string "summary", limit: 256, default: "", null: false
    t.string "details", limit: 4096, default: "", null: false
    t.string "postid", limit: 26, default: "", null: false
    t.string "subjectuserid", limit: 26, default: "", null: false
    t.string "creatoruserid", limit: 26, default: "", null: false
    t.index ["id"], name: "ir_timelineevent_id"
    t.index ["incidentid"], name: "ir_timelineevent_incidentid"
  end

  create_table "ir_userinfo", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "lastdailytododmat"
    t.json "digestnotificationsettingsjson"
  end

  create_table "ir_viewedchannel", primary_key: ["channelid", "userid"], force: :cascade do |t|
    t.string "channelid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
  end

  create_table "jobs", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "type", limit: 32
    t.bigint "priority"
    t.bigint "createat"
    t.bigint "startat"
    t.bigint "lastactivityat"
    t.string "status", limit: 32
    t.bigint "progress"
    t.jsonb "data"
    t.index ["status", "type"], name: "idx_jobs_status_type"
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
    t.index ["client_id", "source_type", "source_period", "transaction_no"], name: "idx_journal_entries_unique_transaction", unique: true
    t.index ["client_id"], name: "index_journal_entries_on_client_id"
    t.index ["date"], name: "idx_journal_entries_date"
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

  create_table "licenses", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.string "bytes", limit: 10000
  end

  create_table "linkmetadata", primary_key: "hash", id: :bigint, default: nil, force: :cascade do |t|
    t.string "url", limit: 2048
    t.bigint "timestamp"
    t.string "type", limit: 16
    t.jsonb "data"
    t.index ["url", "timestamp"], name: "idx_link_metadata_url_timestamp"
  end

  create_table "notifyadmin", primary_key: ["userid", "requiredfeature", "requiredplan"], force: :cascade do |t|
    t.string "userid", limit: 26, null: false
    t.bigint "createat"
    t.string "requiredplan", limit: 100, null: false
    t.string "requiredfeature", limit: 255, null: false
    t.boolean "trial", null: false
    t.bigint "sentat"
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

  create_table "oauthapps", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "creatorid", limit: 26
    t.bigint "createat"
    t.bigint "updateat"
    t.string "clientsecret", limit: 128
    t.string "name", limit: 64
    t.string "description", limit: 512
    t.string "callbackurls", limit: 1024
    t.string "homepage", limit: 256
    t.boolean "istrusted"
    t.string "iconurl", limit: 512
    t.string "mattermostappid", limit: 32, default: "", null: false
    t.index ["creatorid"], name: "idx_oauthapps_creator_id"
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

  create_table "outgoingoauthconnections", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "name", limit: 64
    t.string "creatorid", limit: 26
    t.bigint "createat"
    t.bigint "updateat"
    t.string "clientid", limit: 255
    t.string "clientsecret", limit: 255
    t.string "credentialsusername", limit: 255
    t.string "credentialspassword", limit: 255
    t.text "oauthtokenurl"
    t.enum "granttype", default: "client_credentials", enum_type: "outgoingoauthconnections_granttype"
    t.string "audiences", limit: 1024
    t.index ["name"], name: "idx_outgoingoauthconnections_name"
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

  create_table "persistentnotifications", primary_key: "postid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.bigint "lastsentat"
    t.bigint "deleteat"
    t.integer "sentcount", limit: 2
  end

  create_table "pluginkeyvaluestore", primary_key: ["pluginid", "pkey"], force: :cascade do |t|
    t.string "pluginid", limit: 190, null: false
    t.string "pkey", limit: 150, null: false
    t.binary "pvalue"
    t.bigint "expireat"
  end

  create_table "postacknowledgements", primary_key: ["postid", "userid"], force: :cascade do |t|
    t.string "postid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.bigint "acknowledgedat"
  end

  create_table "postreminders", primary_key: ["postid", "userid"], force: :cascade do |t|
    t.string "postid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.bigint "targettime"
    t.index ["targettime"], name: "idx_postreminders_targettime"
  end

  create_table "posts", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "userid", limit: 26
    t.string "channelid", limit: 26
    t.string "rootid", limit: 26
    t.string "originalid", limit: 26
    t.string "message", limit: 65535
    t.string "type", limit: 26
    t.jsonb "props"
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
    t.index ["createat", "id"], name: "idx_posts_create_at_id"
    t.index ["createat"], name: "idx_posts_create_at"
    t.index ["deleteat"], name: "idx_posts_delete_at"
    t.index ["ispinned"], name: "idx_posts_is_pinned"
    t.index ["originalid"], name: "idx_posts_original_id"
    t.index ["rootid", "deleteat"], name: "idx_posts_root_id_delete_at"
    t.index ["updateat"], name: "idx_posts_update_at"
    t.index ["userid"], name: "idx_posts_user_id"
  end

  create_table "postspriority", primary_key: "postid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "channelid", limit: 26, null: false
    t.string "priority", limit: 32, null: false
    t.boolean "requestedack"
    t.boolean "persistentnotifications"
  end

  create_table "preferences", primary_key: ["userid", "category", "name"], force: :cascade do |t|
    t.string "userid", limit: 26, null: false
    t.string "category", limit: 32, null: false
    t.string "name", limit: 32, null: false
    t.text "value"
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

  create_table "publicchannels", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.bigint "deleteat"
    t.string "teamid", limit: 26
    t.string "displayname", limit: 64
    t.string "name", limit: 64
    t.string "header", limit: 1024
    t.string "purpose", limit: 250
    t.index "lower((displayname)::text)", name: "idx_publicchannels_displayname_lower"
    t.index "lower((name)::text)", name: "idx_publicchannels_name_lower"
    t.index "to_tsvector('english'::regconfig, (((((name)::text || ' '::text) || (displayname)::text) || ' '::text) || (purpose)::text))", name: "idx_publicchannels_search_txt", using: :gin
    t.index ["deleteat"], name: "idx_publicchannels_delete_at"
    t.index ["teamid"], name: "idx_publicchannels_team_id"
    t.unique_constraint ["name", "teamid"], name: "publicchannels_name_teamid_key"
  end

  create_table "reactions", primary_key: ["postid", "userid", "emojiname"], force: :cascade do |t|
    t.string "userid", limit: 26, null: false
    t.string "postid", limit: 26, null: false
    t.string "emojiname", limit: 64, null: false
    t.bigint "createat"
    t.bigint "updateat"
    t.bigint "deleteat"
    t.string "remoteid", limit: 26
    t.string "channelid", limit: 26, default: "", null: false
    t.index ["channelid"], name: "idx_reactions_channel_id"
  end

  create_table "recentsearches", primary_key: ["userid", "searchpointer"], force: :cascade do |t|
    t.string "userid", limit: 26, null: false
    t.integer "searchpointer", null: false
    t.jsonb "query"
    t.bigint "createat", null: false
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
    t.string "pluginid", limit: 190, default: "", null: false
    t.integer "options", limit: 2, default: 0, null: false
    t.index ["siteurl", "remoteteamid"], name: "remote_clusters_site_url_unique", unique: true
  end

  create_table "retentionidsfordeletion", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "tablename", limit: 64
    t.string "ids", limit: 26, array: true
    t.index ["tablename"], name: "idx_retentionidsfordeletion_tablename"
  end

  create_table "retentionpolicies", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "displayname", limit: 64
    t.bigint "postduration"
    t.index ["displayname"], name: "idx_retentionpolicies_displayname"
  end

  create_table "retentionpolicieschannels", primary_key: "channelid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "policyid", limit: 26
    t.index ["policyid"], name: "idx_retentionpolicieschannels_policyid"
  end

  create_table "retentionpoliciesteams", primary_key: "teamid", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.string "policyid", limit: 26
    t.index ["policyid"], name: "idx_retentionpoliciesteams_policyid"
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
    t.string "defaultplaybookadminrole", limit: 64, default: ""
    t.string "defaultplaybookmemberrole", limit: 64, default: ""
    t.string "defaultrunadminrole", limit: 64, default: ""
    t.string "defaultrunmemberrole", limit: 64, default: ""
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
    t.string "roles", limit: 256
    t.boolean "isoauth"
    t.jsonb "props"
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
    t.bigint "lastpostcreateat", default: 0, null: false
    t.string "lastpostcreateid", limit: 26

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
    t.index ["userid", "teamid"], name: "idx_sidebarcategories_userid_teamid"
  end

  create_table "sidebarchannels", primary_key: ["channelid", "userid", "categoryid"], force: :cascade do |t|
    t.string "channelid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.string "categoryid", limit: 128, null: false
    t.bigint "sortorder"
    t.index ["categoryid"], name: "idx_sidebarchannels_categoryid"
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
    t.index ["status", "dndendtime"], name: "idx_status_status_dndendtime"
  end

  create_table "systems", primary_key: "name", id: { type: :string, limit: 64 }, force: :cascade do |t|
    t.string "value", limit: 1024
  end

  create_table "teammembers", primary_key: ["teamid", "userid"], force: :cascade do |t|
    t.string "teamid", limit: 26, null: false
    t.string "userid", limit: 26, null: false
    t.string "roles", limit: 256
    t.bigint "deleteat"
    t.boolean "schemeuser"
    t.boolean "schemeadmin"
    t.boolean "schemeguest"
    t.bigint "createat", default: 0
    t.index ["createat"], name: "idx_teammembers_createat"
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
    t.enum "type", enum_type: "team_type"
    t.string "companyname", limit: 64
    t.string "alloweddomains", limit: 1000
    t.string "inviteid", limit: 32
    t.string "schemeid", limit: 26
    t.boolean "allowopeninvite"
    t.bigint "lastteamiconupdate"
    t.boolean "groupconstrained"
    t.boolean "cloudlimitsarchived", default: false, null: false
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
    t.jsonb "participants"
    t.string "channelid", limit: 26
    t.bigint "threaddeleteat"
    t.string "threadteamid", limit: 26
    t.index ["channelid", "lastreplyat"], name: "idx_threads_channel_id_last_reply_at"
  end

  create_table "tokens", primary_key: "token", id: { type: :string, limit: 64 }, force: :cascade do |t|
    t.bigint "createat"
    t.string "type", limit: 64
    t.string "extra", limit: 2048
  end

  create_table "uploadsessions", id: { type: :string, limit: 26 }, force: :cascade do |t|
    t.enum "type", enum_type: "upload_session_type"
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
    t.index ["displayname"], name: "idx_usergroups_displayname"
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
  add_foreign_key "ir_category_item", "ir_category", column: "categoryid", name: "ir_category_item_categoryid_fkey"
  add_foreign_key "ir_metric", "ir_incident", column: "incidentid", name: "ir_metric_incidentid_fkey"
  add_foreign_key "ir_metric", "ir_metricconfig", column: "metricconfigid", name: "ir_metric_metricconfigid_fkey"
  add_foreign_key "ir_metricconfig", "ir_playbook", column: "playbookid", name: "ir_metricconfig_playbookid_fkey"
  add_foreign_key "ir_playbookautofollow", "ir_playbook", column: "playbookid", name: "ir_playbookautofollow_playbookid_fkey"
  add_foreign_key "ir_playbookmember", "ir_playbook", column: "playbookid", name: "ir_playbookmember_playbookid_fkey"
  add_foreign_key "ir_run_participants", "ir_incident", column: "incidentid", name: "ir_run_participants_incidentid_fkey"
  add_foreign_key "ir_statusposts", "ir_incident", column: "incidentid", name: "ir_statusposts_incidentid_fkey"
  add_foreign_key "ir_timelineevent", "ir_incident", column: "incidentid", name: "ir_timelineevent_incidentid_fkey"
  add_foreign_key "journal_entries", "clients"
  add_foreign_key "journal_entries", "statement_batches"
  add_foreign_key "journal_entry_lines", "journal_entries"
  add_foreign_key "retentionpolicieschannels", "retentionpolicies", column: "policyid", name: "fk_retentionpolicieschannels_retentionpolicies", on_delete: :cascade
  add_foreign_key "retentionpoliciesteams", "retentionpolicies", column: "policyid", name: "fk_retentionpoliciesteams_retentionpolicies", on_delete: :cascade
  add_foreign_key "statement_batches", "clients"
end
