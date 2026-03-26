================================================================================
ISSUE #227 - 目標・受け入れ基準の確認
確認日: 2026-03-26
================================================================================

## 目的・ゴール

### 主目的: 沖縄北部の観光業の実態に合った業種選択肢を整備し、一元管理する
状態: 達成
根拠: Client::INDUSTRIES 定数で7業種（accommodation, restaurant, activity,
      retail, rental_car, beauty, other）を一元管理。
      バリデーション・フォーム・表示すべてが定数を参照する設計。

### 副次的目標: #228の月次レポートで業種別に分析観点を切り替える基盤を整備する
状態: 達成
根拠: Client::INDUSTRIES 定数と industry_label メソッドにより、
      業種keyでの分岐・日本語ラベルでの表示が可能な基盤が整備された。

### 副次的目標: UI上で日本語ラベルを正しく表示する
状態: 達成
根拠: show画面・index画面で industry_label メソッドによる日本語表示を確認済み。
      手動検証ログ（issue227_manual_verification.log）参照。

================================================================================

## 受け入れ基準（必須 Must Have）

### AC-1: Client::INDUSTRIES 定数で業種を一元管理
状態: 達成
実装: app/models/client.rb に INDUSTRIES 定数を定義
      7業種のkey-ラベルペアを Hash で管理

### AC-2: バリデーション・フォーム・表示が定数を参照
状態: 達成
実装:
  - バリデーション: validates :industry, inclusion: { in: INDUSTRIES.keys }
  - フォーム: Client::INDUSTRIES.map { |value, label| [label, value] }
  - 表示: industry_label メソッド（INDUSTRIES[industry]）

### AC-3: show/index画面で日本語ラベル表示
状態: 達成
実装:
  - show.html.erb: @client.industry_label で表示
  - index.html.erb: client.industry_label.presence || "—" で表示
検証: 手動検証ログ参照

### AC-4: 既存データのマイグレーション（hotel→accommodation, tour→activity）
状態: 達成
実装: db/migrate/20260326000000_migrate_client_industry_values.rb
      reversible（up/down 両方定義）

### AC-5: RSpecテスト
状態: 達成
結果: 79 examples, 0 failures
内訳:
  - spec/models/client_spec.rb: 49 examples
    - INDUSTRIES 定数テスト
    - 全7業種のバリデーションテスト
    - 旧値（hotel, tour）が無効であることのテスト
    - industry_label メソッドテスト
    - feature_available? テスト（accommodation ベース）
  - spec/requests/web/clients_spec.rb: 30 examples
    - 作成時に accommodation が保存されることのテスト
    - 更新時に activity が保存されることのテスト
検証: RSpecログ（issue227_rspec_results.log）参照

================================================================================

## 受け入れ基準（推奨 Should Have）

### industry_label メソッド
状態: 達成
実装: Client#industry_label → INDUSTRIES[industry] を返す

================================================================================

## 非機能要件

### NFR-1: 保守性 — 業種の追加・変更はモデルの定数を変更するだけで対応可能
状態: 達成
根拠: INDUSTRIES 定数に1行追加するだけで、バリデーション（INDUSTRIES.keys参照）、
      フォーム（INDUSTRIES.map参照）、表示（industry_label参照）すべてに自動反映。
      DBマイグレーション不要、ビュー修正不要。

### NFR-2: 後方互換性 — 既存データの hotel / tour がある場合はマイグレーションで変換
状態: 達成
根拠: 20260326000000_migrate_client_industry_values.rb で
      hotel → accommodation、tour → activity へのデータ変換を実装。
      reversible 設計のため、ロールバックも可能。

================================================================================
全受け入れ基準: 達成
================================================================================
