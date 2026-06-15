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
end
