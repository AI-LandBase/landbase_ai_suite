# download(読み取り)時のストレージ系エラーを全 *ProcessorService / generator で
# 一貫して分類・メッセージ化するための共有ポリシー (issue#299)。
#
# 本番は ActiveStorage Disk service + worker/platform 間の共有ボリューム(issue#297)のため、
# 権限ミス・ディスクフル・読取専用化が現実的に起きうる。これらはリトライしても回復しないので
# 非リトライ(:storage_error)として扱い、ユーザーにはクラス名を漏らさない固定文言を返す。
module StorageErrorHandling
  # ホスト側ストレージの読み取りで起きうるシステムコールエラー。いずれもリトライで回復しない。
  # ActiveStorage 経由の不在は FileNotFoundError で別途扱うが、生ファイル読み取り
  # (File.binread / vips の tempfile 経路) では ENOENT/EIO が直接上がるため含める。
  # 注意: 一律 SystemCallError で握ると EAGAIN/EINTR 等の一時的エラーまで非リトライ化して
  # しまうため、非リトライが妥当なものだけを明示列挙する。
  STORAGE_SYSTEM_ERRORS = [
    Errno::EACCES,  # 権限なし
    Errno::ENOSPC,  # ディスクフル
    Errno::EROFS,   # 読み取り専用FS
    Errno::ENOENT,  # ファイル/パスが存在しない
    Errno::EIO      # 入出力エラー（ディスク障害等）
  ].freeze

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

  # ユーザーにはクラス名を漏らさない一方、運用トリアージのため元例外を記録する (issue#327)。
  # ディスクフル/権限なのか単なるファイル不在なのかを切り分けられるよう、クラス名と message を残す。
  # level は呼び出し側で使い分ける: システムコール系(EACCES/ENOSPC 等)= :error、
  # ファイル不在(FileNotFoundError) = :warn。
  def log_storage_error(error, level: :error)
    Rails.logger.public_send(level, "[#{self.class.name}] storage error: #{error.class}: #{error.message}")
  end
end
