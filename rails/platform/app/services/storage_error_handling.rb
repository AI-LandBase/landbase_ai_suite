# download(読み取り)時のストレージ系エラーを全 *ProcessorService / generator で
# 一貫して分類・メッセージ化するための共有ポリシー (issue#299)。
#
# 本番は ActiveStorage Disk service + worker/platform 間の共有ボリューム(issue#297)のため、
# 権限ミス・ディスクフル・読取専用化が現実的に起きうる。これらはリトライしても回復しないので
# 非リトライ(:storage_error)として扱い、ユーザーにはクラス名を漏らさない固定文言を返す。
module StorageErrorHandling
  # ホスト側ストレージの読み取りで起きうるシステムコールエラー。
  STORAGE_SYSTEM_ERRORS = [Errno::EACCES, Errno::ENOSPC, Errno::EROFS].freeze

  private

  # 引数なしで raise される ActiveStorage::FileNotFoundError は e.message が
  # クラス名("ActiveStorage::FileNotFoundError")になり、UI/DB にそのまま漏れる。
  # クラス名を出さない固定文言を返す。kind は "PDFファイル" / "画像ファイル" 等。
  def file_not_found_message(kind)
    "#{kind}が見つかりません。もう一度アップロードしてください。"
  end

  def storage_system_error_message(kind)
    "#{kind}をサーバー側で読み込めませんでした。時間をおいて再度お試しください。"
  end
end
