require 'rails_helper'

RSpec.describe Encryption::MultiRegionKmsMigration::ProfileMigrator do
  let(:profile) { create(:profile, :with_pii) }
  let!(:user_password) { profile.user.password }
  let!(:personal_key) { PersonalKeyGenerator.new(profile.user).normalize(profile.personal_key) }

  subject { described_class.new(profile) }

  before do
    allow(IdentityConfig.store).to receive(:aws_kms_multi_region_read_enabled).and_return(true)
  end

  describe '#migrate!' do
    context 'for a user without multi-region ciphertexts' do
      before do
        profile.update!(
          encrypted_pii_multi_region: nil,
          encrypted_pii_recovery_multi_region: nil,
        )
      end

      it 'migrates the single-region ciphertext and saves it to the profile' do
        subject.migrate!

        pii_encryptor = Encryption::Encryptors::PiiEncryptor.new(user_password)

        single_region_pii = pii_encryptor.decrypt(
          Encryption::RegionalCiphertextPair.new(
            single_region_ciphertext: profile.encrypted_pii,
            multi_region_ciphertext: nil,
          ),
          user_uuid: profile.user.uuid,
        )
        multi_region_pii = pii_encryptor.decrypt(
          Encryption::RegionalCiphertextPair.new(
            single_region_ciphertext: nil,
            multi_region_ciphertext: profile.encrypted_pii_multi_region,
          ),
          user_uuid: profile.user.uuid,
        )
        expect(profile.encrypted_pii).to_not eq(profile.encrypted_pii_multi_region)
        expect(single_region_pii).to eq(multi_region_pii)

        pii_recovery_encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)

        single_region_pii_recovery = pii_recovery_encryptor.decrypt(
          Encryption::RegionalCiphertextPair.new(
            single_region_ciphertext: profile.encrypted_pii_recovery,
            multi_region_ciphertext: nil,
          ),
          user_uuid: profile.user.uuid,
        )
        multi_region_pii_recovery = pii_recovery_encryptor.decrypt(
          Encryption::RegionalCiphertextPair.new(
            single_region_ciphertext: nil,
            multi_region_ciphertext: profile.encrypted_pii_recovery_multi_region,
          ),
          user_uuid: profile.user.uuid,
        )
        expect(
          profile.encrypted_pii_recovery,
        ).to_not eq(
          profile.encrypted_pii_recovery_multi_region,
        )
        expect(single_region_pii_recovery).to eq(multi_region_pii_recovery)
      end
    end

    context 'for a user with multi-region ciphertexts' do
      it 'does not modify the profile record' do
        expect { subject.migrate! }.to_not change { profile.attributes }
      end
    end

    context 'for a user without multi-region or single-region ciphertexts' do
      before do
        profile.update!(
          encrypted_pii: nil,
          encrypted_pii_multi_region: nil,
          encrypted_pii_recovery: nil,
          encrypted_pii_recovery_multi_region: nil,
        )
      end

      it 'does not modify the profile record' do
        expect { subject.migrate! }.to raise_error(
          RuntimeError,
          "Profile##{profile.id} is missing encrypted_pii or or encrypted_pii_recovery"
        )
      end
    end
  end
end
