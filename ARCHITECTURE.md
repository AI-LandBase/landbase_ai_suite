# アーキテクチャ設計書

LandBase AI Suite の技術アーキテクチャ詳細設計

**最終更新**: 2026-02-25

---

## 目次

- [システム概要](#システム概要)
- [システム構成](#システム構成)
- [マルチテナント設計](#マルチテナント設計)
- [データベース設計](#データベース設計)
- [API 設計](#api-設計)
- [認証設計](#認証設計)
- [設計パターン](#設計パターン)
- [ADR 参照](#adr-参照)

---

## システム概要

LandBase AI Suite は、沖縄県北部の観光業事業者向けマルチテナント SaaS プラットフォームである。
9 つの AI モジュールで観光業の経営課題を解決する。

| モジュール | 概要 |
|---|---|
| **AnalyticsAI** | 予約・売上・稼働率の可視化、管理会計表、将来予測 |
| **AccountingAI** | 証憑書類の AI-OCR 解析、勘定科目の自動推定と仕訳 |
| **OperationAI** | 清掃・メンテナンススケジュール最適化、シフト自動調整 |
| **OptimaPriceAI** | 需要予測に基づくリアルタイム価格最適化 |
| **ConciergeAI** | 17 言語対応 AI チャットコンシェルジュ |
| **PersonalizeAI** | 顧客プロファイリング、パーソナライズされた滞在提案 |
| **ReputationAI** | 口コミ自動収集・感情分析、返信文案の自動生成 |
| **MarketingAI** | 顧客セグメント分析、OTA・自社サイト戦略最適化 |
| **InventoryAI** | 消耗品の使用量予測、最適発注タイミング算出 |

---

## システム構成

### Docker サービス構成（開発環境）

```
┌─────────────────────────────────────────────────┐
│             LandBase AI Suite                    │
├─────────────┬───────────┬───────────┬───────────┤
│  Platform   │   n8n     │Mattermost │PostgreSQL │
│  Rails 8    │  2.4.0    │   9.11    │    16     │
│  :3000      │  :5678    │  :8065    │  :5432    │
└─────────────┴───────────┴───────────┴───────────┘
```

| サービス | イメージ | 役割 |
|---|---|---|
| **postgres** | postgres:16-bookworm | データベース |
| **platform** | Ruby 3.4.6 / Rails 8.0.2.1 | 基幹アプリ（AI モジュール、API） |
| **n8n** | n8nio/n8n:2.4.0 | ワークフロー自動化（LINE Bot 連携） |
| **mattermost** | mattermost-team-edition:9.11 | チームコミュニケーション |

### 本番環境

```
┌──────────────────────────────────────────┐
│  Caddy（リバースプロキシ）                  │
│  auto HTTPS / Let's Encrypt              │
└──────────────┬───────────────────────────┘
               │ web-proxy-net
┌──────────────▼───────────────────────────┐
│  platform（Platform Rails）               │
│  expose: 3000（内部のみ）                  │
└──────────────┬───────────────────────────┘
               │ internal network
┌──────────────▼───────────────────────────┐
│  db-suite（PostgreSQL 16）                │
│  外部アクセス不可                           │
└──────────────────────────────────────────┘
```

---

## マルチテナント設計

### 分離戦略

| レイヤー | 分離方法 | 詳細 |
|---|---|---|
| **PostgreSQL** | `client_code` / `client_id` 論理分離 | WHERE 句でスコープ |
| **Rails Platform** | `client_code` スコープ | API は `client_code` パラメータ必須 |
| **n8n** | Projects 機能 | Project 単位でワークフロー分離 |
| **Mattermost** | Teams 機能 | Team 単位でチャット分離 |

```ruby
# スコープで分離
JournalEntry.for_client('ikigai_stay')
CleaningManual.for_client('ikigai_stay')
```

---

## データベース設計

### テーブル一覧

```
PostgreSQL 16
└── platform_development
    ├── clients              # クライアント管理
    ├── users                # Web UI 認証（Devise）
    ├── api_tokens           # API Bearer トークン
    ├── journal_entries      # 仕訳ヘッダー（AccountingAI）
    ├── journal_entry_lines  # 仕訳行（借方/貸方の明細行）
    ├── account_masters      # 勘定科目マッピングルール
    ├── statement_batches    # PDF 処理バッチ管理
    ├── cleaning_manuals           # 清掃マニュアル（OperationAI）
    ├── cleaning_sessions          # 清掃セッション（OperationAI）
    ├── cleaning_session_steps     # セッション内ステップ
    ├── cleaning_session_attempts  # ステップ判定試行（AI判定結果）
    └── active_storage_*           # ファイルストレージ（画像・PDF）
```

---

## API 設計

### エンドポイント一覧

全エンドポイントで `Authorization: Bearer <token>` ヘッダーと `client_code` パラメータが必須。

```
# AccountingAI — 経理自動化
POST   /api/v1/amex_statements/process_statement   # Amex PDF アップロード・処理
GET    /api/v1/amex_statements/:id/status           # 処理状況確認
GET    /api/v1/journal_entries                       # 仕訳一覧（フィルタ・ページネーション）
GET    /api/v1/journal_entries/:id                   # 仕訳詳細
PATCH  /api/v1/journal_entries/:id                   # 仕訳編集
GET    /api/v1/journal_entries/export                # CSV エクスポート

# OperationAI — 清掃マニュアル生成
POST   /api/v1/cleaning_manuals/generate             # 画像から AI 生成
GET    /api/v1/cleaning_manuals                      # マニュアル一覧
GET    /api/v1/cleaning_manuals/:id                  # マニュアル詳細
GET    /api/v1/cleaning_manuals/:id/status           # 生成状況確認

# OperationAI — 清掃セッション（インタラクティブ実行）
POST   /api/v1/cleaning_manuals/:id/cleaning_sessions  # セッション作成
GET    /api/v1/cleaning_sessions/:id                    # セッション詳細
GET    /api/v1/cleaning_sessions/:id/current_step       # 現在ステップ取得
POST   /api/v1/cleaning_sessions/:id/judge              # AI 写真判定
PATCH  /api/v1/cleaning_sessions/:id/skip               # ステップスキップ
PATCH  /api/v1/cleaning_sessions/:id/suspend            # セッション中断
PATCH  /api/v1/cleaning_sessions/:id/resume             # セッション再開
GET    /api/v1/cleaning_sessions/:id/report             # 完了レポート
```

### リクエスト例

```
Authorization: Bearer <token>
GET /api/v1/journal_entries?client_code=ikigai_stay&source_type=amex&status=review_required
```

### エラーレスポンス

```json
{ "error": "Unauthorized" }
{ "error": "client_code parameter is required" }
{ "error": "Client not found" }
```

---

## 認証設計

### 二重認証方式

| 対象 | 方式 | 用途 |
|---|---|---|
| **Web UI** | Devise（セッション認証） | 管理画面ログイン |
| **API** | Bearer トークン | n8n・外部サービス連携 |

### API トークン認証フロー

```
1. トークン生成
   ApiToken.generate!(name: "n8n", expires_at: 3.months.from_now)
   → [token_record, raw_token]  # raw_token はこの時だけ表示

2. DB 保存
   token_digest = SHA256(raw_token)  # ハッシュのみ保存

3. API リクエスト
   Authorization: Bearer <raw_token>

4. 認証処理
   → SHA256(raw_token) で token_digest を検索
   → 有効期限チェック
   → last_used_at 更新

5. テナントスコープ
   → client_code パラメータで @current_client 設定
   → 以降のクエリはすべてクライアントスコープ
```

---

## 設計パターン

### Service Object

複雑なビジネスロジックをコントローラーから分離。

| サービス | 責務 |
|---|---|
| `CleaningManualGeneratorService` | Claude Vision API で客室写真から清掃マニュアル生成 |
| `CleaningSessionService` | 清掃セッションの状態管理（開始・判定・スキップ・中断/再開・完了・レポート） |
| `CleaningPhotoJudgeService` | Claude Vision API で清掃写真の OK/NG 同期判定 |
| `AmexStatementProcessorService` | Claude API で Amex PDF を仕訳データに変換 |
| `BankStatementProcessorService` | Claude API で銀行明細 PDF を仕訳データに変換 |
| `InvoiceProcessorService` | Claude API で請求書 PDF を仕訳データに変換 |

### 仕訳データモデル（ヘッダー + 明細行）

```
JournalEntry（仕訳ヘッダー）
├── client_id, date, source_type, description, status ...
└── has_many :journal_entry_lines

JournalEntryLine（仕訳行）
├── side: debit / credit
├── account, sub_account, department, partner
├── tax_category, invoice, amount
└── belongs_to :journal_entry
```

- 単一仕訳 = 2行（借方1 + 貸方1）
- 複合仕訳 = 3行以上（例: 給与支払い 借方1 / 貸方3）
- 貸借一致バリデーション: 仕訳単位で借方合計 == 貸方合計

### 非同期ジョブ（Solid Queue）

AI 処理は非同期ジョブで実行し、ステータスをポーリングで確認。

| ジョブ | サービス | リトライ |
|---|---|---|
| `CleaningManualGenerateJob` | CleaningManualGeneratorService | 2 回 / 5 秒間隔 |
| `AmexStatementProcessJob` | AmexStatementProcessorService | 2 回 / 5 秒間隔 |

```
POST /api/v1/cleaning_manuals/generate
  → CleaningManualGenerateJob.perform_later
    → CleaningManualGeneratorService (Claude API)
      → cleaning_manual.status = "draft"

GET /api/v1/cleaning_manuals/:id/status
  → { "status": "draft", "data": { ... } }
```

---

## ADR 参照

- [ADR 0001: n8n + Mattermost + Rails 統合](./docs/adr/0001-n8n-mattermost-rails-integration.md)
- [ADR 0002: フロント/バックオフィス分離](./docs/adr/0002-frontend-backend-separation.md)
- [ADR 0005: マルチテナント戦略](./docs/adr/0005-multitenancy-strategy.md)
- [ADR 0006: Platform 基幹アプリ分離](./docs/adr/0006-platform-app-separation.md)
- [ADR 0007: Caddy リバースプロキシ](./docs/adr/0007-caddy-reverse-proxy-multi-domain.md)

---

**Last Updated**: 2026-03-07
