require 'rails_helper'

RSpec.describe DocumentMetadata do
  let(:fields) do
    {
      document_number: 'D1234567',
      document_issued: '2021-05-05',
      document_expiration: '2031-05-05',
    }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:encrypted_document_data) }

    it 'is invalid without document data' do
      record = build(:document_metadata, encrypted_document_data: nil)

      expect(record).not_to be_valid
      expect(record.errors[:encrypted_document_data]).to be_present
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:document_capture_session) }
    it { is_expected.to belong_to(:profile).optional }
  end

  describe 'encrypted document data at rest' do
    it 'stores the fields encrypted and round-trips them' do
      record = create(:document_metadata, document_data: fields)

      expect(record.encrypted_document_data).to be_present
      expect(record.encrypted_document_data).not_to include('D1234567')
      expect(record.reload.document_data).to eq(fields)
    end

    it 'keeps only the known fields' do
      record = create(:document_metadata, document_data: fields.merge(ssn: '900-00-1234'))

      expect(record.reload.document_data.keys).to match_array(DocumentMetadata::FIELDS)
    end

    it 'survives attribute_encryption_key rotation via the old-key queue' do
      record = create(:document_metadata, document_data: fields)
      old_key = IdentityConfig.store.attribute_encryption_key

      allow(IdentityConfig.store).to receive(:attribute_encryption_key)
        .and_return('a-brand-new-32-byte-rotated-key!')
      allow(IdentityConfig.store).to receive(:attribute_encryption_key_queue)
        .and_return([{ 'key' => old_key }])

      expect(record.reload.document_data).to eq(fields)
    end
  end

  describe 'retention scopes' do
    before do
      allow(IdentityConfig.store).to receive(:document_images_ttl_seconds).and_return(3.days.to_i)
    end

    let!(:fresh) { create(:document_metadata, created_at: 3.days.ago + 1.hour) }
    let!(:stale) { create(:document_metadata, created_at: 3.days.ago - 1.hour) }

    it 'separates retained from expired around the retention window' do
      expect(DocumentMetadata.retained).to contain_exactly(fresh)
      expect(DocumentMetadata.expired).to contain_exactly(stale)
      expect(fresh.retained?).to eq(true)
      expect(stale.retained?).to eq(false)
    end
  end

  describe 'uniqueness' do
    it 'allows only one row per capture session' do
      session = create(:document_capture_session)
      create(:document_metadata, document_capture_session: session)

      dup = build(:document_metadata, document_capture_session: session)
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
