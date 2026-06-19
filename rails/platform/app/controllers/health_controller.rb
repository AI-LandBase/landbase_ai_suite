# storage(ActiveStorage の保存先)の書き込み可否を実際に試す healthcheck エンドポイント。
# Rails 標準の /up は boot 確認のみで storage の破損(権限不一致・マウント消失・RO化・
# ディスクフル・I/Oエラー)を検知できない。実書き込み→削除を行うことで、test -w では
# 拾えないディスクフル/I/Oエラーも含めて storage 健全性を検出する (issue#330, issue#331)。
#
# 現状 dev/prod とも ActiveStorage は :local(Disk service)前提。S3 等の外部サービスへ
# 移行した場合、ローカルファイルへの write では健全性を判定できないため要見直し。
#
# ApplicationController を継承せず ActionController::Base 直下にすることで
# authenticate_user! を回避する(LB/compose からの無認証アクセスを許可)。GET のみのため
# CSRF 対策は不要(Rails の forgery protection は非 GET のみ対象)。
class HealthController < ActionController::Base
  def storage
    path = storage_healthcheck_path
    # 実書き込みの成否が storage 健全性の本体。delete はあくまで後始末であり、
    # 連続実行時の削除レース(既に消えている等)を 503 と誤判定しないよう cleanup 側で握りつぶす。
    File.write(path, "ok")
    head :ok
  rescue SystemCallError, IOError => e
    # File への write 失敗は Errno::*(SystemCallError) / IOError として上がる。
    # storage 無関係の例外まで 503 に丸めないよう、storage 起因の例外型に絞る。
    Rails.logger.error("[health/storage] storage write check failed: #{e.class}: #{e.message}")
    head :service_unavailable
  ensure
    cleanup(path)
  end

  private

  # ActiveStorage Disk service の保存先直下の隠しファイルを使う。
  # ドット始まりにすることで ActiveStorage のキー(hex)スキャン対象と衝突しない。
  # platform/worker が同じ storage を共有するため、worker(.healthcheck.worker)と
  # ファイル名を分離して書き込み/削除の競合による誤検知を避ける。
  def storage_healthcheck_path
    root = ActiveStorage::Blob.service.try(:root) || Rails.root.join("storage")
    File.join(root, ".healthcheck.platform")
  end

  # 後始末はベストエフォート。削除失敗(既に消えている等)は健全性判定に影響させない。
  def cleanup(path)
    File.delete(path) if path && File.exist?(path)
  rescue SystemCallError
    nil
  end
end
