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
| `ANTHROPIC_API_KEY` | Claude API（レシート画像→仕訳変換） | `app/services/receipt_processor_service.rb` |

これらを変更した後は `docker compose -f compose.production.yaml --env-file .env.production up -d --force-recreate platform worker` で反映する（`restart` では再評価されない）。

## Client.line_user_id 紐付けポリシー

`Client.line_user_id` は **業務上のLINEアカウント（クライアント窓口）** を紐付けることを想定している。1 Client につき 1 LINE アカウントの 1:1 関係。

LINE Webhook が未登録の `line_user_id` から来た場合、`LineWebhookController#handle_message` が「このLINEアカウントは未登録です。管理者にお問い合わせください。」と返信する。

### 現状（2026-06-01 時点）

| Client | code | line_user_id | 備考 |
|---|---|---|---|
| Parijona (id=1) | parijona | 開発者の個人 LINE user ID を一時的に紐付け | E2E疎通テスト用の紐付け。本番運用LINEアカウントが決まり次第差し替える |
| AAcart (id=2) | aacart | nil | 未紐付け |

> **メモ**: 本番運用LINEアカウントが確定したら、`Client.find(1).update!(line_user_id: "U...")` で差し替える。開発者IDを紐付けたままだと、開発者がテストで送った画像が本番Clientのデータとして保存される。

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

`Client.line_user_id` に該当 user ID が登録されていない。`docker compose exec platform bin/rails runner "..."` で紐付ける。

### ジョブが失敗キューに溜まっている

```ruby
SolidQueue::FailedExecution.order(created_at: :desc).limit(5)
SolidQueue::FailedExecution.find(id).retry  # リトライ
```

## 関連

- `docs/guides/vps-deployment.md` — VPS全体のデプロイ手順
- PR #226 — LINE Webhook 連携基盤
- PR #284 — worker 外部疎通修正
