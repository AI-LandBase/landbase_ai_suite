---
name: monthly-report
description: クライアントの月次オペレーション分析レポートをAI生成します
---

# 月次オペレーション分析レポート生成スキル

## メタデータ

- **名前**: monthly-report
- **説明**: クライアントの仕訳データを基に、Anthropic APIで月次オペレーション分析レポートを自動生成する
- **トリガー**: ユーザーが月次レポートの生成・作成を依頼したとき
- **関連 Issue**: #228

---

## 処理手順

### Step 1: パラメータ確認

ユーザーから以下を確認する:
- **クライアントコード** (client_code): 必須
- **対象年月** (year_month): YYYY-MM形式。指定がなければ前月を使用

### Step 2: Rails consoleでレポート生成

以下のコマンドをDockerコンテナ内で実行する:

```bash
docker compose -f compose.development.yaml --env-file .env.development exec platform bash -lc "bin/rails runner \"
  client = Client.find_by!(code: 'CLIENT_CODE')
  service = MonthlyReportGeneratorService.new(client: client, year_month: 'YYYY-MM')
  result = service.call
  if result.success?
    puts 'レポート生成成功: ID=#{result.data.id}'
    puts result.data.content
  else
    puts 'エラー: #{result.error}'
  end
\""
```

### Step 3: 結果確認

- 成功: Web UIで閲覧可能であることを案内（`/monthly_reports/{id}?client_code=CLIENT_CODE`）
- 失敗: エラー内容を確認し、原因を調査

---

## 業種別分析観点

レポートはクライアントの`industry`フィールドに基づき、業種別の分析観点を自動切り替えする:

| 業種 | industry値 | 主な分析観点 |
|------|-----------|-------------|
| 宿泊業 | hotel | 稼働率、客単価、清掃コスト比率、季節変動 |
| 飲食業 | restaurant | 原価率、仕入先分析、食材ロス、人件費率 |
| アクティビティ | tour | 参加者数推移、天候連動、季節プログラム |
| その他 | nil等 | 汎用的な収支バランス、固変分析 |

---

## 月次一括生成

全activeクライアントの前月分レポートを一括生成するRakeタスク:

```bash
docker compose -f compose.development.yaml --env-file .env.development exec platform bash -lc "bin/rails reports:generate_monthly"
```
