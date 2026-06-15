# LINE Bot 本番運用メモ

LINE Messaging API を使った領収書画像処理機能の本番運用に関する記録と手順。

## 構成

```
LINE ユーザー
  ↓ 画像送信
LINE Messaging API
  ↓ Webhook POST
https://parijona.land-bank.ai/webhook/line
  ↓
LineWebhookController#receive (Rails)
  ↓ enqueue
ReceiptLineProcessJob (SolidQueue, worker コンテナ)
  ↓ get_content
api-data.line.me (LINE Content API)
  ↓ 画像バイナリ取得
ReceiptProcessorService → Anthropic Claude API
  ↓
JournalEntry / JournalEntryLine 作成
  ↓ push
LINE ユーザーへ結果返信
```

## 過去の経緯

- 〜2026-03-15 頃: LINE Webhook は n8n Cloud (`https://yuri-parijona.app.n8n.cloud/webhook/line-webhook`) で受けていた
- 2026-06-01: Rails 直接受信に切替。n8n Cloud 側のルートは LINE 側設定から外した（n8n 自体は廃止していない）

## 必要な環境変数

本番 `/srv/landbase_ai_suite/.env.local` に設定。

| キー | 用途 | 参照箇所 |
|---|---|---|
| `LINE_CHANNEL_SECRET` | Webhook 署名検証 | `app/controllers/line_webhook_controller.rb` |
| `LINE_CHANNEL_TOKEN` | Messaging API (push / get_content) | `app/services/line_messaging_service.rb` |
| `LINE_DEFAULT_CLIENT_CODE` | 友だち追加時に自動紐付ける Client コード（例: `parijona`） | `app/controllers/line_webhook_controller.rb` |
| `ANTHROPIC_API_KEY` | Claude API（レシート画像→仕訳変換） | `app/services/receipt_processor_service.rb` |

これらを変更した後は `docker compose -f compose.production.yaml --env-file .env.production up -d --force-recreate platform worker` で反映する（`restart` では再評価されない）。

## LINE アカウント紐付けポリシー（LineFollower）

LINE user と Client の紐付けは **`line_followers` テーブル**で管理する（`Client has_many :line_followers`、1 Client : N LINE user）。`clients.line_user_id` カラムは 2026-06-01 のリファクタリングで廃止済み。

紐付けの流れ:

1. **友だち追加（`follow` イベント）** → `LineWebhookController#handle_follow` が `ENV["LINE_DEFAULT_CLIENT_CODE"]` の Client に対し `LineFollower.find_or_create_by!(line_user_id:)` で**自動登録**（承認フローなし）。`LINE_DEFAULT_CLIENT_CODE` が未設定 or 該当 Client が無い場合は登録されず、「サービスの初期設定が完了していません。管理者にお問い合わせください。」と返信する。
2. **レシート画像送信（`message`/image）** → `handle_message` が `LineFollower.find_by(line_user_id:)&.client` で Client を逆引きし、`ReceiptLineProcessJob` をエンキューする。
3. 逆引きできない（未登録の）user から画像が来た場合は「このLINEアカウントは未登録です。一度ブロックを解除して友だち追加し直してください。」と返信する。

### 紐付けの確認・差し替え

`clients.line_user_id` は存在しないため、`Client#update!(line_user_id:)` は使えない。`LineFollower` レコードを操作する。

```ruby
# 確認
LineFollower.find_by(line_user_id: "U...")&.client

# 別 Client へ付け替え
LineFollower.find_by(line_user_id: "U...").update!(client: Client.find_by(code: "..."))

# 紐付け解除（以後その user の画像は未登録扱い）
LineFollower.find_by(line_user_id: "U...").destroy
```

### 現状（2026-06-01 時点）

| Client | code | LINE 運用 | 備考 |
|---|---|---|---|
| Parijona (id=1) | parijona | 動作確認用の暫定 LINE アカウントを `LineFollower` として登録 | 疎通テスト用。本番運用アカウントが決まり次第差し替える |
| AAcart (id=2) | aacart | 未対応 | 必要なら別チャネルで運用 |

> **メモ**: 暫定アカウントを登録したままだと、テスト送信した画像が当該 Client のデータとして保存される。本番アカウント確定後は上記の付け替え/解除で差し替えること。

## 動作確認手順

### 1. Webhook 疎通

```bash
# 署名なしリクエストは 401 が返るのが正常（環境変数が読めている証拠）
curl -sk -o /dev/null -w "%{http_code}\n" -X POST https://parijona.land-bank.ai/webhook/line
# 期待: 401
```

LINE Developers コンソール → Messaging API設定 → Webhook URL 横の「検証」ボタンで `Success` が出れば OK。

### 2. worker コンテナの外部疎通

```bash
ssh devuser@parijona.land-bank.ai
cd /srv/landbase_ai_suite
docker compose -f compose.production.yaml --env-file .env.production exec worker bash -lc \
  "getent hosts api-data.line.me; getent hosts api.anthropic.com"
# 期待: 両方とも IPアドレスが返る
```

返らない場合は `compose.production.yaml` の `worker.networks` に `web-proxy-net` が含まれているか確認（PR #284 で対応済み）。

### 3. ログ追跡

```bash
# Webhook受信
docker compose -f compose.production.yaml --env-file .env.production logs platform --since 5m | grep webhook/line

# ジョブ実行
docker compose -f compose.production.yaml --env-file .env.production logs worker --since 5m | grep ReceiptLine
```

## トラブルシュート

### 401 が返り続ける

`LINE_CHANNEL_SECRET` が未設定か、値が間違っている。`compose up -d --force-recreate` で再評価が必要。

### ジョブが Socket::ResolutionError で失敗する

worker から外部 DNS が引けない。`docker compose ps` でネットワーク設定を確認、必要なら `web-proxy-net` を追加。

### 「このLINEアカウントは未登録です」と返信される

その `line_user_id` の `LineFollower` レコードが無い（＝友だち追加イベントを経ていない、または登録に失敗した）。通常は一度ブロック解除して友だち追加し直せば `handle_follow` で自動登録される。それでも登録されない場合は次を確認:

- `LINE_DEFAULT_CLIENT_CODE` が本番 `.env.local` に設定され、該当 Client が存在するか（未設定だと友だち追加時に登録されない）
- 必要なら Rails console で手動登録: `LineFollower.find_or_create_by!(line_user_id: "U...") { |f| f.client = Client.find_by(code: "parijona") }`

### ジョブが失敗キューに溜まっている

```ruby
SolidQueue::FailedExecution.order(created_at: :desc).limit(5)
SolidQueue::FailedExecution.find(id).retry  # リトライ
```

## 関連

- `docs/guides/vps-deployment.md` — VPS全体のデプロイ手順
- PR #226 — LINE Webhook 連携基盤
- PR #284 — worker 外部疎通修正
