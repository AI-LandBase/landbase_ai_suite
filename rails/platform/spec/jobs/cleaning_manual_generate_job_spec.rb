require "rails_helper"

RSpec.describe CleaningManualGenerateJob, type: :job do
  let(:client) { create(:client) }
  let(:manual) { create(:cleaning_manual, :processing, client: client) }

  let(:mock_result) do
    CleaningManualGeneratorService::Result.new(
      success: true,
      data: { property_name: "テスト", areas: [], supplies_needed: [], total_estimated_minutes: 0 },
      error: nil,
      reason: nil
    )
  end

  before do
    manual.images.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )
    allow(CleaningManualGeneratorService).to receive(:new).and_return(
      instance_double(CleaningManualGeneratorService, call: mock_result)
    )
  end

  it "成功時にステータスをdraftに更新すること" do
    described_class.perform_now(manual.id)

    manual.reload
    expect(manual.status).to eq("draft")
    expect(manual.manual_data).to be_present
    expect(manual.error_message).to be_nil
  end

  context "non-retryableな失敗の場合" do
    let(:mock_result) do
      CleaningManualGeneratorService::Result.new(
        success: false, data: {}, error: "APIキー未設定", reason: :config_error
      )
    end

    it "ステータスをfailedに更新すること" do
      described_class.perform_now(manual.id)

      manual.reload
      expect(manual.status).to eq("failed")
      expect(manual.error_message).to eq("APIキー未設定")
    end
  end

  context "retryableな失敗の場合" do
    let(:mock_result) do
      CleaningManualGeneratorService::Result.new(
        success: false, data: {}, error: "Anthropic API エラー: timeout", reason: :api_error
      )
    end

    it "RetryableErrorをraiseすること" do
      job = described_class.new(manual.id)

      expect { job.perform(manual.id) }.to raise_error(CleaningManualGenerateJob::RetryableError, "Anthropic API エラー: timeout")
    end
  end

  context "file_not_found の場合" do
    let(:mock_result) do
      CleaningManualGeneratorService::Result.new(
        success: false, data: {}, error: "画像ファイルが見つかりません: ActiveStorage::FileNotFoundError", reason: :file_not_found
      )
    end

    it "リトライせずステータスをfailedに更新すること" do
      described_class.perform_now(manual.id)

      manual.reload
      expect(manual.status).to eq("failed")
      expect(manual.error_message).to include("画像ファイルが見つかりません")
    end
  end

  it "レコードが存在しない場合は静かに終了すること" do
    expect {
      described_class.perform_now(-1)
    }.not_to raise_error
  end

  it "既にprocessingでないレコードはスキップすること" do
    manual.update!(status: "draft", manual_data: { foo: "bar" })

    described_class.perform_now(manual.id)

    expect(CleaningManualGeneratorService).not_to have_received(:new)
  end
end
