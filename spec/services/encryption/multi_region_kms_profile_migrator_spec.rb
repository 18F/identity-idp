require 'rails_helper'

RSpec.describe Encryption::MultiRegionKmsProfileMigrator do
  let(:profile) { create(:profile, pii: pii) }
  let(:user_password) { profile.user.password }
  let(:personal_key) { PersonalKeyGenerator.new(profile.user).normalize(profile.personal_key) }
  let(:pii) do
    {
      dob: '1920-01-01',
      ssn: '666-66-1234',
      first_name: 'Jane',
      last_name: 'Doe',
      zipcode: '20001',
    }
  end

  subject { described_class.new(profile) }

  before do
    allow(IdentityConfig.store).to receive(:aws_kms_multi_region_read_enabled).and_return(true)
  end

  describe '#migrate!' do
    context 'for a user without multi-region ciphertexts' do
      it 'migrates the single-region ciphertext and saves it to the profile' do
        pii_encryptor = Encryption::Encryptors::PiiEncryptor.new(user_password)
        profile.encrypted_pii = pii_encryptor.encrypt(pii.to_json, user_uuid: profile.user.uuid)
        recovery_pii_encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)
        profile.encrypted_pii_recovery = recovery_pii_encryptor.encrypt(
          pii.to_json, user_uuid: profile.user.uuid
        )
        profile.encrypted_pii_multi_region = nil
        profile.encrypted_pii_recovery_multi_region = nil
        profile.save
        subject.migrate!

        pii_encryptor = Encryption::Encryptors::PiiEncryptor.new(user_password)

        single_region_pii = pii_encryptor.decrypt(
          profile.encrypted_pii,
          user_uuid: profile.user.uuid,
        )
        multi_region_pii = pii_encryptor.decrypt(
          profile.encrypted_pii_multi_region,
          user_uuid: profile.user.uuid,
        )

        expect(profile.encrypted_pii).to_not be_blank
        expect(profile.encrypted_pii_multi_region).to_not be_blank
        expect(profile.encrypted_pii).to_not eq(profile.encrypted_pii_multi_region)
        expect(single_region_pii).to eq(multi_region_pii)

        pii_recovery_encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)

        single_region_pii_recovery = pii_recovery_encryptor.decrypt(
          profile.encrypted_pii_recovery,
          user_uuid: profile.user.uuid,
        )
        multi_region_pii_recovery = pii_recovery_encryptor.decrypt(
          profile.encrypted_pii_recovery_multi_region,
          user_uuid: profile.user.uuid,
        )

        expect(profile.encrypted_pii_recovery).to_not be_blank
        expect(profile.encrypted_pii_recovery_multi_region).to_not be_blank
        expect(profile.encrypted_pii_recovery).to_not eq(
          profile.encrypted_pii_recovery_multi_region,
        )

        expect(single_region_pii_recovery).to eq(multi_region_pii_recovery)
      end
    end

    context 'for a user with multi-region ciphertexts' do
      it 'does not modify the profile record' do
        expect do
          pii_encryptor = Encryption::Encryptors::PiiEncryptor.new(user_password)
          profile.encrypted_pii = pii_encryptor.encrypt(pii.to_json, user_uuid: profile.user.uuid)
          recovery_pii_encryptor = Encryption::Encryptors::PiiEncryptor.new(personal_key)
          profile.encrypted_pii_recovery = recovery_pii_encryptor.encrypt(
            pii.to_json, user_uuid: profile.user.uuid
          )
          profile.save

          subject.migrate!
        end.to_not change {
          profile.attributes.slice(
            :encrypted_pii,
            :encrypted_pii_multi_region,
            :encrypted_pii_recovery,
            :encrypted_pii_recovery_multi_region,
          )
        }
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
          "Profile##{profile.id} is missing encrypted_pii or encrypted_pii_recovery",
        )
      end
    end
  end
end
