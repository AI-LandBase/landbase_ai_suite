# LandBase AI Suite

**AI ドリブン経営支援プラットフォーム**
沖縄県北部の観光業向けマルチテナント自動化スイート

[![Rails](https://img.shields.io/badge/Rails-8.0-red)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791)](https://www.postgresql.org/)
[![n8n](https://img.shields.io/badge/n8n-2.4.0-6e1e78)](https://n8n.io/)
[![Mattermost](https://img.shields.io/badge/Mattermost-9.11-0058cc)](https://mattermost.com/)
[![License](https://img.shields.io/badge/License-Proprietary-yellow)](#ライセンス)

---

## 📋 目次

- [概要](#概要)
- [主な特徴](#主な特徴)
- [クイックスタート](#クイックスタート)
- [プロジェクト構成](#プロジェクト構成)
- [技術スタック](#技術スタック)
- [ドキュメント](#ドキュメント)
- [開発に参加](#開発に参加)
- [ライセンス](#ライセンス)

---

## 概要

LandBase AI Suite は、沖縄県北部の小規模観光業（ホテル、飲食店、ツアー会社など）向けに開発された **SaaS 型マルチテナントプラットフォーム** です。各クライアント（法人・個人事業主）に対して、専用の自動化環境とコミュニケーションツールを提供します。

### ビジョン

> データドリブン経営を AI ソリューションでサポートする

観光業界の課題（人手不足、データ活用の遅れ、OTA 依存）を、AI とワークフロー自動化で解決します。

---

## 主な特徴

LandBase AI Suite は、観光業の経営課題を解決する 9 つの AI モジュールを提供します。

| モジュール | 概要 |
|---|---|
| **AnalyticsAI** | 予約・売上・稼働率のリアルタイム可視化、管理会計表の作成、AI による将来予測 |
| **AccountingAI** | 証憑書類の AI-OCR 解析、勘定科目の自動推定と仕訳、会計ソフト連携 |
| **OperationAI** | 清掃・メンテナンススケジュール最適化、シフト自動調整、業務効率分析 |
| **OptimaPriceAI** | 需要予測に基づくリアルタイム価格最適化、競合価格の自動モニタリング |
| **ConciergeAI** | 17 言語対応 AI チャットコンシェルジュ、予約対応、観光スポット推薦 |
| **PersonalizeAI** | 顧客プロファイリング、パーソナライズされた滞在提案、ロイヤルティ管理 |
| **ReputationAI** | 口コミ自動収集・感情分析、改善ポイント特定、返信文案の自動生成 |
| **MarketingAI** | 顧客セグメント分析、OTA・自社サイト戦略最適化、プロモーション効果測定 |
| **InventoryAI** | 消耗品・アメニティの使用量予測、最適発注タイミング算出、在庫コスト最適化 |

---

## クイックスタート

### 必要な環境

- Docker 20.10+
- Docker Compose 2.0+
- Git 2.30+
- Make

### セットアップ手順

#### 1. リポジトリクローン

```bash
git clone https://github.com/zomians/landbase_ai_suite.git
cd landbase_ai_suite
```

#### 2. 環境変数設定

```bash
cp .env.local.example .env.local
# .env.local を編集（以下の情報を設定）
# - LINE Bot 認証情報（LINE Developers Consoleで取得）
```

#### 3. サービス起動

```bash
# 全サービス起動
make up

# 起動確認
make logs
```

#### 4. 各サービスにアクセス

| サービス             | URL                   | 備考                           |
| -------------------- | --------------------- | ------------------------------ |
| **Platform**         | http://localhost:3000 | プラットフォーム基幹アプリ     |
| **n8n**              | http://localhost:5678 | 初回アクセス時にアカウント作成 |
| **Mattermost**       | http://localhost:8065 | 初回アクセス時にセットアップ   |

### よく使うコマンド

```bash
# サービス管理
make up                    # 全サービス起動（PostgreSQL, Platform, Mattermost, n8n）
make down                  # 全サービス停止
make logs                  # 全サービスログ表示
make clean                 # 完全クリーンアップ（注意：データ削除）
make postgres-shell        # PostgreSQLシェル接続

# LINE Bot 連携
make ngrok                 # ngrokでn8nを公開（LINE Webhook用）
make ngrok-stop            # ngrok停止
make ngrok-status          # ngrok状態確認

# 本番デプロイ
make prod-deploy           # Platformデプロイ（build → up → db:prepare）
make prod-logs             # 本番ログ表示
```

---

## プロジェクト構成

```
landbase_ai_suite/
├── .claude/                       # Claude Code設定
├── docs/
│   ├── adr/                       # Architecture Decision Records
│   ├── business/                  # ビジネス関連ドキュメント
│   ├── guides/                    # セットアップ・技術ガイド
│   └── templates/                 # 見積書・請求書テンプレート
├── n8n/
│   └── workflows/                 # n8nワークフローテンプレート
├── rails/
│   └── platform/                  # プラットフォーム基幹アプリ
├── reverse-proxy/                 # Caddyリバースプロキシ（本番用）
├── .env.development               # 開発環境変数設定
├── .env.production                # 本番環境変数設定
├── .env.local.example             # 機密情報テンプレート
├── compose.development.yaml       # Docker Compose定義（開発）
├── compose.production.yaml        # Docker Compose定義（本番）
├── Makefile                       # 開発自動化コマンド
├── README.md                      # このファイル
├── CLAUDE.md                      # Claude向けガイド
├── CONTRIBUTING.md                # 開発者向け実践ガイド
└── ARCHITECTURE.md                # 技術アーキテクチャ詳細
```

---

## 技術スタック

### インフラストラクチャ層

| 技術               | バージョン | 用途               |
| ------------------ | ---------- | ------------------ |
| **Docker**         | 20.10+     | コンテナ化         |
| **Docker Compose** | 2.0+       | マルチコンテナ管理 |
| **PostgreSQL**     | 16-alpine  | データベース       |

### 自動化・コミュニケーション層

| 技術           | バージョン | 用途                                      |
| -------------- | ---------- | ----------------------------------------- |
| **n8n**        | 2.4.0    | ワークフロー自動化エンジン（OperationAI） |
| **Mattermost** | 9.11       | チームコミュニケーション                  |

### アプリケーション層

| 技術                | 用途                         |
| ------------------- | ---------------------------- |
| **Ruby on Rails**   | Platform 基幹（8.0.2.1）    |
| **Devise**          | ユーザー認証                 |
| **Anthropic SDK**   | AI 連携（Claude API）       |
| **Tailwind CSS**    | ユーティリティファースト CSS |
| **Stimulus**        | インタラクティブ JS          |
| **Solid Queue**     | バックグラウンドジョブ       |
| **Solid Cache**     | キャッシュレイヤー           |
| **Solid Cable**     | WebSocket                    |
| **Kaminari**        | ページネーション             |

**詳細**: [ARCHITECTURE.md](./ARCHITECTURE.md)

---

## ドキュメント

| ドキュメント        | 役割                                               |
| ------------------- | -------------------------------------------------- |
| **CONTRIBUTING.md** | 開発規約（Issue、Git、コミット、コーディング規約） |
| **ARCHITECTURE.md** | 技術アーキテクチャ詳細、DB 設計、API 設計          |
| **CLAUDE.md**       | AI 向けクイックリファレンス                        |

### Architecture Decision Records

- [0001: n8n + Mattermost + Rails 統合](./docs/adr/0001-n8n-mattermost-rails-integration.md)
- [0002: フロント/バックオフィス分離](./docs/adr/0002-frontend-backend-separation.md)
- [0005: マルチテナント戦略](./docs/adr/0005-multitenancy-strategy.md)
- [0006: Platform 基幹アプリ分離](./docs/adr/0006-platform-app-separation.md)
- [0007: Caddy リバースプロキシ](./docs/adr/0007-caddy-reverse-proxy-multi-domain.md)
- [0008: リポジトリ分割](./docs/adr/0008-repository-split.md)（撤回）
- [0009: AccountingAI 機能拡張のスコープと優先順位（2026-06）](./docs/adr/0009-accounting-feature-scope-2026-06.md)
- [0010: parijona 向け AccountingAI を fork で独立進化させる](./docs/adr/0010-fork-for-parijona-accounting-ai.md) — parijona 向け開発は fork 先リポで行う

---

## 開発に参加

開発ワークフロー・コミット規約・コーディング規約は **[CONTRIBUTING.md](./CONTRIBUTING.md)** を参照してください。

---

## ライセンス

All rights reserved. © 株式会社 AI.LandBase

---

**Last Updated**: 2026-02-25
