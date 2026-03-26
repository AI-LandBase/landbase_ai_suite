================================================================================
ISSUE #227 - RSpec自動テスト実行ログ
実行日: 2026-03-26
環境: Docker (platform container) / PostgreSQL 16 / Rails 8.0.2.1 / Ruby 3.4.6
テストDB: platform_test
================================================================================

Client
  バリデーション
    必須カラム
      有効なファクトリが正常に動作する
      codeが空の場合無効
      nameが空の場合無効
    code
      重複する場合無効
    status
      activeは有効
      trialは有効
      inactiveは有効
      無効なstatusの場合エラー
    industry
      accommodationは有効
      restaurantは有効
      activityは有効
      retailは有効
      rental_carは有効
      beautyは有効
      otherは有効
      nilは有効
      旧値hotelは無効
      旧値tourは無効
      無効なindustryの場合エラー
  #to_param
    codeを返す
  #status_label
    activeは「有効」を返す
    trialは「トライアル」を返す
    inactiveは「無効」を返す
  STATUSES
    全ステータスが定義されている
  INDUSTRIES
    全業種が定義されている
  #industry_label
    accommodationは「宿泊業」を返す
    restaurantは「飲食業」を返す
    activityは「アクティビティ」を返す
    nilの場合はnilを返す
  スコープ
    .active
      activeステータスのクライアントのみ取得する
    .visible
      activeとtrialのクライアントを取得する
    .search
      コードで部分一致検索できる
      名前で部分一致検索できる
      大文字小文字を区別しない
      空文字列の場合は全件返す
      nilの場合は全件返す
      SQLインジェクションを防ぐ（%や_をエスケープ）
  関連
    journal_entriesを持てる
    account_mastersを持てる
  #feature_available?
    業種デフォルト
      hotelクライアントはcleaning_manualsが利用可能
      restaurantクライアントはcleaning_manualsが利用不可
      activityクライアントはcleaning_manualsが利用不可
      industry未設定のクライアントはcleaning_manualsが利用不可
    servicesオーバーライド
      servicesでtrueに設定するとrestaurantでも利用可能
      servicesでfalseに設定するとhotelでも利用不可
    引数の型
      Symbolでも動作する
      Stringでも動作する

Web::Clients
  GET /clients (index)
    未認証の場合
      ログイン画面にリダイレクトすること
    認証済みの場合
      200を返すこと
      activeとtrialのクライアントが表示されること
      検索でフィルタできること
      結果が空の場合メッセージが表示されること
  GET /clients/:code (show)
    未認証の場合
      ログイン画面にリダイレクトすること
    認証済みの場合
      200を返すこと
      クライアント情報が表示されること
      機能カードのリンクが表示されること
      hotelクライアントは清掃マニュアルカードが表示されること
      非hotelクライアントは清掃マニュアルカードが表示されないこと
      存在しないコードの場合リダイレクトすること
  GET /clients/new (new)
    未認証の場合
      ログイン画面にリダイレクトすること
    認証済みの場合
      200を返すこと
      フォームが表示されること
  POST /clients (create)
    未認証の場合
      ログイン画面にリダイレクトすること
    認証済みの場合
      正常なパラメータで作成できること
      バリデーションエラー時にフォームが再表示されること
      code重複時にエラーが表示されること
  GET /clients/:code/edit (edit)
    未認証の場合
      ログイン画面にリダイレクトすること
    認証済みの場合
      200を返すこと
      編集フォームが表示されること
      存在しないコードの場合リダイレクトすること
  PATCH /clients/:code (update)
    未認証の場合
      ログイン画面にリダイレクトすること
    認証済みの場合
      正常に更新できること
      codeが変更されないこと
      バリデーションエラー時にフォームが再表示されること
  DELETE /clients/:code (destroy)
    未認証の場合
      ログイン画面にリダイレクトすること
    認証済みの場合
      論理削除されること（statusがinactiveに変更）
      物理削除されないこと
      フラッシュメッセージが表示されること
  GET / (root)
    認証済みの場合
      クライアント一覧が表示されること

Finished in 8.27 seconds (files took 21.75 seconds to load)
79 examples, 0 failures
