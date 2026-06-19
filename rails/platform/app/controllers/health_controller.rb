# storage(ActiveStorage の保存先)の書き込み可否を実際に試す healthcheck エンドポイント。
# Rails 標準の /up は boot 確認のみで storage の破損(権限不一致・マウント消失・RO化・
# ディスクフル・I/Oエラー)を検知できない。実書き込み→削除を行うことで、test -w では
# 拾えないディスクフル/I/Oエラーも含めて storage 健全性を検出する (issue#330, issue#331)。
#
# ApplicationController を継承せず ActionController::Base 直下にすることで
# authenticate_user! を回避する(LB/compose からの無認証アクセスを許可)。
class HealthController < ActionController::Base
  def storage
    path = storage_healthcheck_path
    File.write(path, "ok")
    File.delete(path)
    head :ok
  rescue => e
    Rails.logger.error("[health/storage] storage write check failed: #{e.class}: #{e.message}")
    head :service_unavailable
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
end
