require 'rails_helper'

RSpec.describe DocumentArtifact do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:image_type) }
    it { is_expected.to validate_presence_of(:storage_name) }

    it 'rejects unknown image types' do
      artifact = build(:document_artifact, image_type: 'fingerprint')
      expect(artifact).not_to be_valid
      expect(artifact.errors[:image_type]).to be_present
    end

    it 'enforces one artifact per image type per profile' do
      profile = create(:profile)
      create(:document_artifact, profile:, image_type: 'front')
      dup = build(:document_artifact, profile:, image_type: 'front')

      expect { dup.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:document_capture_session) }
    it { is_expected.to belong_to(:profile).optional }
  end

  describe 'encryption key at rest' do
    let(:raw_key) { Base64.strict_encode64(SecureRandom.bytes(32)) }

    it 'stores the key encrypted and round-trips it' do
      artifact = create(:document_artifact, encryption_key: raw_key)

      expect(artifact.encrypted_encryption_key).to be_present
      expect(artifact.encrypted_encryption_key).not_to eq(raw_key)
      expect(artifact.reload.encryption_key).to eq(raw_key)
    end

    it 'handles a blank key' do
      artifact = build(:document_artifact)
      artifact.encryption_key = nil

      expect(artifact.encrypted_encryption_key).to be_nil
      expect(artifact.encryption_key).to be_nil
    end

    it 'survives attribute_encryption_key rotation via the old-key queue' do
      artifact = create(:document_artifact, encryption_key: raw_key)
      old_key = IdentityConfig.store.attribute_encryption_key

      allow(IdentityConfig.store).to receive(:attribute_encryption_key)
        .and_return('a-brand-new-32-byte-rotated-key!')
      allow(IdentityConfig.store).to receive(:attribute_encryption_key_queue)
        .and_return([{ 'key' => old_key }])

      expect(artifact.reload.encryption_key).to eq(raw_key)
    end
  end

  describe 'retention scopes' do
    before do
      allow(IdentityConfig.store).to receive(:document_images_retention_days).and_return(90)
    end

    let!(:fresh) { create(:document_artifact, created_at: 89.days.ago) }
    let!(:stale) { create(:document_artifact, created_at: 91.days.ago) }

    it 'separates retained from expired around the retention window' do
      expect(DocumentArtifact.retained).to contain_exactly(fresh)
      expect(DocumentArtifact.expired).to contain_exactly(stale)
    end
  end
end
