require 'rails_helper'

RSpec.describe MultiRegionKmsMigration::UserMigrationJob do
  before do
    allow(IdentityConfig.store).to receive(:aws_kms_multi_region_read_enabled).and_return(true)
  end

  let!(:multi_region_password_digest_user) { create(:user, password: 'salty pickles') }
  let!(:single_region_password_digest_user) do
    user = create(:user, password: 'salty_pickles')
    user.update!(encrypted_password_digest_multi_region: nil)
    user
  end
  let!(:uak_password_digest_user) do
    user = create(:user, password: nil)
    user.update!(
      encrypted_password_digest: Encryption::UakPasswordVerifier.digest('salty pickles'),
    )
    user
  end

  let!(:multi_region_recovery_code_digest_user) { create(:user, personal_key: '1234-ABCD') }
  let!(:single_region_recovery_code_digest_user) do
    user = create(:user, personal_key: '1234-ABCD')
    user.update!(encrypted_recovery_code_digest_multi_region: nil)
    user
  end
  let!(:uak_password_recovery_code_user) do
    user = create(:user, personal_key: nil)
    user.update!(
      encrypted_recovery_code_digest: Encryption::UakPasswordVerifier.digest('1234-ABCD'),
    )
    user
  end

  describe '#perform' do
    it 'does not modify records that do have multi-region ciphertexts' do
      original_encrypted_password_digest_multi_region =
        multi_region_password_digest_user.encrypted_password_digest_multi_region
      original_encrypted_recovery_code_digest_multi_region =
        multi_region_recovery_code_digest_user.encrypted_recovery_code_digest_multi_region

      described_class.perform_now

      expect(
        multi_region_password_digest_user.reload.encrypted_password_digest_multi_region,
      ).to eq(
        original_encrypted_password_digest_multi_region,
      )
      expect(
        multi_region_recovery_code_digest_user.reload.encrypted_recovery_code_digest_multi_region,
      ).to eq(
        original_encrypted_recovery_code_digest_multi_region,
      )
    end

    it 'migrates records that do not have multi-region ciphertexts' do
      described_class.perform_now

      aggregate_failures do
        expect(
          single_region_password_digest_user.reload.encrypted_password_digest_multi_region,
        ).to_not be_blank
        expect(
          single_region_recovery_code_digest_user.reload.encrypted_recovery_code_digest_multi_region, # rubocop:disable Layout/LineLength
        ).to_not be_blank
      end
    end

    xcontext 'when errors occur' do
      let(:profile_migrator) { double(Encryption::MultiRegionKmsMigration::ProfileMigrator) }

      before do
        allow(profile_migrator).to receive(:migrate!).and_raise(RuntimeError, 'test error')
        allow(
          Encryption::MultiRegionKmsMigration::ProfileMigrator,
        ).to receive(:new).and_return(profile_migrator)
      end

      it 'logs the error' do
        analytics = subject.analytics

        expect(analytics).to receive(:track_event).twice.with(
          'Multi-region KMS migration: Profile migrated',
          success: false,
          profile_id: instance_of(Integer),
          exception: instance_of(String),
        )
        expect(analytics).to receive(:track_event).with(
          'Multi-region KMS migration: Profile migration summary',
          profile_count: 2,
          success_count: 0,
          error_count: 2,
        )

        subject.perform_now
      end

      it 'aborts after it encounters too many errors' do
        # rubocop:disable Rails/SkipsModelValidations
        create_list(:profile, 11, :with_pii)
        Profile.update_all(
          encrypted_pii_multi_region: nil,
          encrypted_pii_recovery_multi_region: nil,
        )
        # rubocop:enable Rails/SkipsModelValidations

        subject.perform_now

        expect(profile_migrator).to have_received(:migrate!).exactly(10).times
      end
    end
  end

  xdescribe '#find_profiles_to_migrate' do
    it 'returns the profiles that need to be migrated' do
      results = subject.find_profiles_to_migrate(statement_timeout: 120, profile_count: 2)

      expect(results).to match_array(single_region_ciphertext_profiles)
    end

    context 'when a profile does not include PII' do
      let(:profiles) { create_list(:profile, 4) }

      it 'does not return the profile' do
        results = subject.find_profiles_to_migrate(statement_timeout: 120, profile_count: 2)

        expect(results).to be_empty
      end
    end
  end
end
