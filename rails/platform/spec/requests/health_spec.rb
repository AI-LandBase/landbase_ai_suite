require "rails_helper"

RSpec.describe "Health", type: :request do
  describe "GET /health/storage" do
    it "storage への書き込みに成功すると 200 を返す（認証不要）" do
      get "/health/storage"

      expect(response).to have_http_status(:ok)
    end

    it "healthcheck 用の一時ファイルを残さない" do
      get "/health/storage"

      root = ActiveStorage::Blob.service.try(:root) || Rails.root.join("storage")
      expect(File.exist?(File.join(root, ".healthcheck.platform"))).to be(false)
    end

    it "storage への書き込みが失敗すると 503 を返す（ディスクフル等）" do
      allow(File).to receive(:write).and_raise(Errno::ENOSPC, "No space left on device")

      get "/health/storage"

      expect(response).to have_http_status(:service_unavailable)
    end

    it "後始末の削除が失敗（連続実行で既に削除済み等）でも 200 を返す" do
      root = ActiveStorage::Blob.service.try(:root) || Rails.root.join("storage")
      path = File.join(root, ".healthcheck.platform")
      allow(File).to receive(:delete).with(path).and_raise(Errno::ENOENT)

      get "/health/storage"

      expect(response).to have_http_status(:ok)
    ensure
      FileUtils.rm_f(path)
    end
  end
end
