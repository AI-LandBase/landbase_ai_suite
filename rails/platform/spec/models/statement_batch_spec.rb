require "rails_helper"

RSpec.describe StatementBatch, type: :model do
  describe "バリデーション" do
    subject { build(:statement_batch) }

    it "有効なファクトリが正常に動作する" do
      expect(subject).to be_valid
    end

    it "clientが空の場合無効" do
      subject.client = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:client]).to be_present
    end

    describe "source_type" do
      %w[amex bank invoice receipt].each do |valid_type|
        it "#{valid_type}は有効" do
          subject.source_type = valid_type
          expect(subject).to be_valid
        end
      end

      it "無効なsource_typeの場合エラー" do
        subject.source_type = "invalid"
        expect(subject).not_to be_valid
        expect(subject.errors[:source_type]).to be_present
      end

      it "source_typeが空の場合無効" do
        subject.source_type = nil
        expect(subject).not_to be_valid
      end
    end

    describe "status" do
      %w[processing completed failed].each do |valid_status|
        it "#{valid_status}は有効" do
          subject.status = valid_status
          expect(subject).to be_valid
        end
      end

      it "無効なstatusの場合エラー" do
        subject.status = "invalid"
        expect(subject).not_to be_valid
        expect(subject.errors[:status]).to be_present
      end
    end
  end

  describe "アソシエーション" do
    it "journal_entriesを持つ" do
      batch = create(:statement_batch)
      entry = create(:journal_entry, client: batch.client, statement_batch: batch)

      expect(batch.journal_entries).to contain_exactly(entry)
    end

    it "削除時に紐づく journal_entries と journal_entry_lines も一緒に削除される (dependent: :destroy)" do
      batch = create(:statement_batch)
      create(:journal_entry, client: batch.client, statement_batch: batch,
             debit_amount: 1000, credit_amount: 1000)

      expect { batch.destroy }
        .to change(JournalEntry, :count).by(-1)
        .and change(JournalEntryLine, :count).by(-2)
    end
  end

  describe "スコープ" do
    describe ".for_client" do
      it "指定クライアントのバッチのみ取得する" do
        client_a = create(:client, code: "client_a")
        client_b = create(:client, code: "client_b")
        batch_a = create(:statement_batch, client: client_a)
        create(:statement_batch, client: client_b)

        result = described_class.for_client("client_a")
        expect(result).to contain_exactly(batch_a)
      end
    end

    describe ".recent" do
      it "新しい順に並ぶ" do
        old = create(:statement_batch, created_at: 1.day.ago)
        new_batch = create(:statement_batch, created_at: Time.current)

        result = described_class.recent
        expect(result.first).to eq(new_batch)
        expect(result.last).to eq(old)
      end
    end
  end

  describe "マルチテナント分離" do
    it "異なるクライアントのデータが混在しない" do
      client_a = create(:client, code: "client_a")
      client_b = create(:client, code: "client_b")
      create(:statement_batch, client: client_a)
      create(:statement_batch, client: client_b)

      expect(described_class.for_client("client_a").count).to eq(1)
      expect(described_class.for_client("client_b").count).to eq(1)
    end
  end

  describe ".ingest! (issue#302)" do
    let(:client) { create(:client) }
    let(:attachable) do
      { io: StringIO.new("\xFF\xD8\xFFreceipt_image".b), filename: "r.jpg", content_type: "image/jpeg" }
    end

    context "成功時" do
      it "永続化済みの processing バッチを返し、pdf が添付される" do
        batch = described_class.ingest!(
          client: client, source_type: "receipt", fingerprint: "fp_ok", attachable: attachable
        )

        expect(batch).to be_persisted
        expect(batch.status).to eq("processing")
        expect(batch.source_type).to eq("receipt")
        expect(batch.pdf_fingerprint).to eq("fp_ok")
        expect(batch.pdf).to be_attached
      end
    end

    # ActiveStorage は実 upload を after_commit で行うため、upload 失敗時には
    # batch 行が先に processing でコミットされる。その孤児を残さないことを検証する。
    context "after_commit の upload が失敗する時" do
      before do
        allow_any_instance_of(ActiveStorage::Blob)
          .to receive(:upload_without_unfurling).and_raise(Errno::ENOSPC, "No space left on device")
      end

      it "IngestError を raise し、元例外を cause_error に保持する" do
        expect {
          described_class.ingest!(client: client, source_type: "receipt", fingerprint: "fp_ng", attachable: attachable)
        }.to raise_error(StatementBatch::IngestError) { |e| expect(e.cause_error).to be_a(Errno::ENOSPC) }
      end

      it "processing のままロックされる孤児バッチを残さない" do
        expect {
          begin
            described_class.ingest!(client: client, source_type: "receipt", fingerprint: "fp_ng", attachable: attachable)
          rescue StatementBatch::IngestError
            nil
          end
        }.not_to change { described_class.where(status: "processing").count }
      end

      it "コミット済みのバッチを failed に確定する（dedup から外れ再送ロックしない）" do
        begin
          described_class.ingest!(client: client, source_type: "receipt", fingerprint: "fp_ng", attachable: attachable)
        rescue StatementBatch::IngestError
          nil
        end

        batch = described_class.where(client: client, pdf_fingerprint: "fp_ng").first
        expect(batch).to be_present
        expect(batch.status).to eq("failed")
        expect(batch.error_message).to include("取り込み失敗")
      end
    end
  end
end
