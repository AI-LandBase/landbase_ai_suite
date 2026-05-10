# ADR 0008: リポジトリ分割（landbase_ai_suite / AccountingAI / service_core）

## ステータス

採用（Accepted）

## 日付

2026-05-10

## コンテキスト（背景・課題）

ADR 0006 で「Platform 基幹アプリ + クライアント固有アプリ」の分離を採用したが、開発が進むにつれて当初想定とのズレが顕在化した。

### 現リポジトリの実態

`landbase_ai_suite` には性質の異なる 3 種類の資産が同居している:

1. **会社・総務系コンテンツ**（LandBase 自身の運営資産）
   - 会社紹介・README
   - 名刺デザインテンプレート（issue #275）
   - 自社発行用の請求書生成 skill (`invoice-generator`)
   - 業務委託契約書生成 skill (`contract-generator`)
   - 貢献度測定 skill (`contribution-meter`、issue #273)
   - 形態は Markdown / Claude Skills 中心、軽量

2. **経理 AI SaaS（AccountingAI）**（運営: parijona、LandBase グループの AI モジュール群の一つ）
   - PDF 取込パイプライン（Amex / 銀行 / 請求書 / 領収書 → 仕訳）
   - 仕訳・勘定科目・複合仕訳データモデル
   - 弥生会計 CSV エクスポート
   - LINE Webhook（領収書受信）
   - マルチテナント基盤（client_code 論理分離）
   - Rails + n8n + Mattermost + PostgreSQL + Caddy の重量スタック

3. **ホテル系機能**（本リポでは稼働クライアントなし）
   - 清掃マニュアル生成（hotel 限定、issue #249 でフィーチャーゲート済み）
   - **既存の別リポジトリ `service_core`（ホテル業務基盤 SaaS）への移植が決定済み**

### 課題

- **デプロイ結合**: 軽量な総務系コンテンツの編集だけでも、Docker 4 サービスを起動できる環境が必要
- **リリース粒度の乖離**: 顧客向け SaaS（経理）と社内資産（総務）のリリースサイクルが大きく異なる
- **アクセス管理**: 経理データに関わるコードと社内資産のコントリビュータ範囲を分離したい
- **ADR 0006 の前提変化**: 「複数クライアント共通の Platform」を志向していたが、実態は経理ドメイン専用 SaaS。Platform は AccountingAI（運営: parijona）として、経理会社が複数の経理クライアントを管理する独立 SaaS とすべき
- **ブランド整合**: 既存の AI モジュール群（MarketingAI、AnalyticsAI 等、ADR 0005 参照）と命名規則を揃えると `AccountingAI` が自然

### ビジネス要件

- parijona は経理会社として複数クライアントを抱えるため、**マルチテナント機構（client_code 論理分離）は継続維持**
- 総務系コンテンツは Markdown / Skills の編集に最適化された軽量リポにしたい
- ホテル系（清掃マニュアル）は既存の `service_core`（ホテル業務基盤 SaaS）に移植して統合運用する

## 検討した選択肢

### 選択肢1: 現状維持（モノレポ継続）

**メリット**:
- 移行コストゼロ

**デメリット**:
- ❌ 総務系コンテンツ編集にも重量 Docker スタックが必要
- ❌ アクセス権限を分離できない
- ❌ 顧客 SaaS と社内資産が同一 issue tracker・CI で混在

**不採用の理由**: 上記課題が解決しない。

### 選択肢2: skill ごと過分割（不採用）

例: 各 skill を個別リポ化

**デメリット**:
- ❌ skill ごとリポ分割は管理コストに見合わない
- ❌ YAGNI 原則に反する

### 選択肢3: 業種・責務別の 3 リポ構成（採用）

- `landbase_ai_suite`（残すリポ）: 会社紹介 + 総務系 Skills + 名刺テンプレ。軽量 Markdown リポ
- `accounting_ai`（新規リポ）: AccountingAI（経理 AI SaaS、運営: parijona）。Rails + n8n + Mattermost + PostgreSQL、マルチテナント
- `service_core`（既存リポ）: ホテル業務基盤 SaaS。cleaning_manuals 一式の移管先

**メリット**:
- ✅ 責務が明確（社内資産 / 経理 SaaS / ホテル SaaS）
- ✅ 業種別のクライアント獲得・運用サイクルを完全分離
- ✅ 軽量側（landbase）は Docker 不要で編集可能
- ✅ 既存 `service_core` への合流でホテル機能を活かせる（削除回避）
- ✅ 顧客 SaaS のデプロイ・アクセス権限を業種別に集約

**デメリット**:
- ⚠️ 初期整備（CI、本番デプロイ、ドメイン）の二重化
- ⚠️ 共通 ADR の参照関係に手当てが必要
- ⚠️ `service_core` の現 README（Norn OS / スキースクール）とホテル基盤としての位置付けに乖離があり、整理が必要

## 決定

**現リポジトリを `landbase_ai_suite`（軽量化）と `accounting_ai`（AccountingAI、新設）に分割し、ホテル系機能は既存の `service_core` リポジトリに移植する。**

> リポ名は snake_case で `accounting_ai`、プロダクト・ブランド名は `AccountingAI`（既存の MarketingAI / AnalyticsAI と命名規則を揃える）。

### A. `landbase_ai_suite`（残すリポ・本リポジトリ）

**役割**: 会社紹介 + 総務系資産（LandBase 自身の運営）

**残すもの**:
- `README.md`（会社・AI Suite 概要に書き直し）
- `docs/business/`、`docs/templates/`（名刺など）
- `docs/adr/`（既存 ADR 一式、履歴保持）
- `.claude/skills/invoice-generator/`
- `.claude/skills/contract-generator/`
- `.claude/skills/contribution-meter/`（feature/273 マージ後に取り込み）
- `CLAUDE.md`（軽量 Markdown リポ向けに簡略化）

**削除するもの**:
- `rails/`
- `n8n/`
- `reverse-proxy/`
- `compose.development.yaml`、`compose.production.yaml`
- `.env.development`、`.env.production`、`.env.local`、`.env.local.example`
- `Makefile`（または軽量版に置換）
- `ARCHITECTURE.md`、`CONTRIBUTING.md`（経理 SaaS 向けは accounting_ai に移管、必要なら新規作成）
- 経理系 skills: `bank-statement-processor`、`amex-statement-processor`、`invoice-processor`
- ホテル系 skill: `cleaning-manual-generator`

### B. `accounting_ai`（新規リポ・AccountingAI）

**役割**: AccountingAI（経理 AI SaaS）。運営は parijona、複数の経理クライアントをマルチテナントで管理する。

**含むもの**:

| 領域 | 対象 |
|------|------|
| アプリ本体 | `rails/platform` 一式 |
| マルチテナント基盤 | `Client`, `User`/Devise, `ApiToken`, `client_code` スコープ |
| 経理コアモデル | `JournalEntry`, `JournalEntryLine`, `StatementBatch`, `AccountMaster` |
| 取込サービス | `AmexStatementProcessorService`, `BankStatementProcessorService`, `InvoiceProcessorService`, `ReceiptProcessorService` |
| 出力 | `YayoiExportService`（弥生 CSV） |
| 通信 | `LineWebhookController`, `LineMessagingService` |
| インフラ | n8n, Mattermost, PostgreSQL, Caddy reverse-proxy, Dockerfile / compose 一式 |
| Skills | `bank-statement-processor`, `amex-statement-processor`, `invoice-processor` |
| 関連 ADR コピー | 0001, 0002, 0005, 0006, 0007（必要に応じ再解釈） |

**含めないもの**:
- 会社・総務系資産（landbase_ai_suite に残置）
- ホテル系機能（削除）

### C. `service_core`（既存リポ・ホテル業務基盤 SaaS）

**役割**: Ikigai Stay 他ホテルクライアント向けマルチテナント SaaS。ホテル業務全般の基盤。

**本 ADR で移植するもの**（清掃マニュアル一式）:
- `app/models/cleaning_manual.rb`
- `app/controllers/cleaning_manuals_controller.rb`
- `app/services/cleaning_manual_generator_service.rb`
- `app/views/cleaning_manuals/`
- 関連マイグレーション、spec、フィーチャーゲート（issue #249 関連）
- `.claude/skills/cleaning-manual-generator/`

**移植方針**:
- 清掃マニュアルは `service_core` 内のホテル業務機能の一つとして組み込み
- 現 `landbase_ai_suite` の git 履歴は保持（移植元の追跡用）
- 移植後、`landbase_ai_suite` および `accounting_ai` からは削除

### 機能マッピング（決定版）

| 機能 | landbase_ai_suite | accounting_ai | service_core | 備考 |
|------|:-:|:-:|:-:|------|
| 会社紹介・README | ✓ | | | 書き直し |
| 名刺デザインテンプレ | ✓ | | | issue #275 |
| invoice-generator skill | ✓ | | | 自社発行用 |
| contract-generator skill | ✓ | | | 業務委託契約 |
| contribution-meter skill | ✓ | | | feature/273 |
| Rails platform（経理） | | ✓ | | |
| マルチテナント基盤（経理） | | ✓ | | client_code 維持 |
| Journal/Account/Batch モデル | | ✓ | | |
| Amex/Bank/Invoice/Receipt processors | | ✓ | | |
| YayoiExportService | | ✓ | | |
| LineWebhookController | | ✓ | | 領収書受信 |
| n8n / Mattermost / PostgreSQL / Caddy | | ✓ | | AccountingAI 用に完全移管 |
| 経理系 skills（bank/amex/invoice-processor） | | ✓ | | |
| 清掃マニュアル一式（model/controller/service/view/skill） | 削除 | 削除 | ✓ 移植 | service_core で統合 |
| 既存 ADR | ✓ | ✓ (関連分コピー) | 必要に応じ参照 | 0008 は全リポに残す |

### 移行戦略

#### Phase 1: 清掃マニュアル一式を `service_core` に移植

1. `service_core` 側で受け入れ用ブランチを作成（例: `feat/integrate-cleaning-manuals`）
2. 現リポから清掃マニュアル関連ファイルをコピー:
   - `app/models/cleaning_manual.rb`
   - `app/controllers/cleaning_manuals_controller.rb`
   - `app/services/cleaning_manual_generator_service.rb`
   - `app/views/cleaning_manuals/`
   - 関連マイグレーション、spec、フィーチャーゲート
   - `.claude/skills/cleaning-manual-generator/`
3. `service_core` のマルチテナント・モデル基盤に整合させて統合（命名・スコープの調整）
4. PR レビュー後マージし、本番動作確認
5. 移植元（現リポ）の参照ブランチ・コミット SHA を ADR に追記

#### Phase 2: accounting_ai の立ち上げ

1. `git clone --mirror git@github.com:zomians/landbase_ai_suite.git accounting_ai.git`
2. GitHub に新規リポジトリ `zomians/accounting_ai`（または別 org）を作成
3. `git push --mirror` で全履歴・全ブランチを移送
4. `main` から不要ファイルを削除する単一コミット:
   - 総務系: `.claude/skills/{invoice-generator,contract-generator,contribution-meter}/`
   - 名刺・会社紹介: `docs/business/`, `docs/templates/`
   - 清掃マニュアル一式（Phase 1 で移植済みのため削除）
5. README / CLAUDE.md / CONTRIBUTING.md / ARCHITECTURE.md を AccountingAI 文脈で書き直し
6. CI/CD・本番デプロイ先・環境変数を accounting_ai 側に再設定

#### Phase 3: landbase_ai_suite の軽量化

1. `main` で削除コミット:
   - `rails/`, `n8n/`, `reverse-proxy/`
   - `compose.*.yaml`, `.env.*`, `Makefile`
   - 経理系 skills、`cleaning-manual-generator` skill
   - `ARCHITECTURE.md`, `CONTRIBUTING.md`（必要なら新規簡易版に置換）
2. `README.md` を「会社紹介 + 総務系 Skills 一覧」に書き直し
3. `CLAUDE.md` を Markdown / Skills リポ向けに簡略化（Docker・経理規約セクション削除）

#### Phase 4: インフラ移管

- 本番 n8n / Mattermost / PostgreSQL / Caddy インスタンスは `accounting_ai` 側で運用
- LINE Webhook URL、ngrok 設定、ドメイン DNS を accounting_ai 側に紐付け直す
- 旧 landbase 本番環境は停止または retire
- `service_core` のインフラは現状維持（独立運用）

### コミット規約

両リポとも既存規約 `<type>(<scope>): <subject> (issue#XX)` を継承。issue 番号は各リポで独立採番。

## 結果

### 期待効果

1. **責務の明確化**: 社内資産（landbase）/ 経理 SaaS（AccountingAI、運営: parijona）/ ホテル SaaS（service_core）が業種別に物理分離
2. **編集の軽量化**: 総務系コンテンツ更新に Docker 不要
3. **アクセス管理**: 経理データ・ホテルデータへのアクセス権限を業種別リポに集約
4. **デプロイ独立**: 業種別 SaaS のリリースサイクルが社内資産から完全分離
5. **ADR 0006 の整合性回復**: AccountingAI・service_core それぞれが「マルチテナント Platform」となり、当初構想が業種別スコープで成立
6. **清掃機能の有効活用**: 既存 `service_core` への合流により、ホテル業務基盤の一部として継続運用
7. **ブランド統一**: MarketingAI / AnalyticsAI と並ぶ `AccountingAI` として LandBase の AI モジュール群に位置付けられる

### トレードオフ

- ⚠️ 初期整備コスト（landbase / accounting_ai 双方の CI、デプロイ、ドメイン、README、および service_core 側の統合作業）
- ⚠️ 清掃マニュアルの `service_core` への適合作業（マルチテナント設計・命名規約の調整）
- ⚠️ 移行直後は ADR 参照関係（0001/0002/0005/0006/0007）の解釈変更が必要
- ⚠️ `service_core` の現 README（Norn OS / スキースクール）と「ホテル業務基盤」としての位置付けに乖離があり、整理が必要

### 関連 ADR への影響

| ADR | 影響 |
|-----|------|
| ADR 0001（n8n + Mattermost + Rails 統合） | accounting_ai 側に継承 |
| ADR 0002（フロント/バックオフィス分離） | AccountingAI 内部の設計思想として継承 |
| ADR 0005（マルチテナント戦略） | AccountingAI 内部に完全継承 |
| ADR 0006（Platform 基幹アプリ分離） | **再解釈が必要**: 「LandBase 共通 Platform」→「AccountingAI（parijona 運営）の経理 SaaS Platform」 |
| ADR 0007（Caddy リバースプロキシ） | accounting_ai 側に継承 |

## 未決事項（Future Work）

- **Issue 移行**: 既存 GitHub Issue を accounting_ai / service_core 側にどう持ち越すか（ラベル別エクスポート / 手動移送 / 一部のみ）
- **本番ドメイン設計**: AccountingAI のサブドメイン構成（例: `accounting.landbase.jp` / `ai.parijona.jp` / 独自ドメイン）
- **GitHub Org**: accounting_ai を `zomians` org のまま置くか、parijona 用 org を新設するか
- **ブランド表記の統一**: コード内・UI 表示・ドキュメントでの `AccountingAI` 表記の徹底（参考: MarketingAI / AnalyticsAI）
- **service_core の位置付け整理**: 現 README（Norn OS / スキースクール）と「Ikigai Stay 他ホテル向けマルチテナント SaaS」としての位置付けの整合（README 改訂 or 別 ADR で再定義）
- **清掃マニュアルの service_core 内設計**: 既存の `service_core` モデル・スキーマとの統合粒度（独立モジュール / 既存機能への組込）

## 参考資料

- [ADR 0002: フロント/バックオフィス分離](./0002-frontend-backend-separation.md)
- [ADR 0005: マルチテナント実装戦略](./0005-multitenancy-strategy.md)
- [ADR 0006: Platform 基幹アプリ分離](./0006-platform-app-separation.md)
- [ADR 0007: Caddy リバースプロキシ](./0007-caddy-reverse-proxy-multi-domain.md)
