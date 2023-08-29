require 'rails_helper'

RSpec.describe MultiRegionKmsMigration::ProfileMigrationJob do
  let!(:profiles) { create_list(:profile, 4, :with_pii) }
  let!(:single_region_ciphertext_profiles) do
    single_region_profiles = profiles[2..3]
    single_region_profiles.each do |profile|
      profile.update!(
        encrypted_pii_multi_region: nil,
        encrypted_pii_recovery_multi_region: nil,
      )
    end
    single_region_profiles
  end
  let!(:multi_region_ciphertext_profiles) { profiles[0..1] }

  describe '#perform' do
    it 'does not modify records that do have multi-region ciphertexts' do
      profile = multi_region_ciphertext_profiles.first

      original_encrypted_pii_multi_region = profile.encrypted_pii_multi_region
      original_encrypted_pii_recovery_multi_region = profile.encrypted_pii_recovery_multi_region

      described_class.perform_now

      expect(profile.reload.encrypted_pii_multi_region).to eq(
        original_encrypted_pii_multi_region,
      )
      expect(profile.encrypted_pii_recovery_multi_region).to eq(
        original_encrypted_pii_recovery_multi_region,
      )
    end

    it 'migrates records that do not have multi-region ciphertexts' do
      described_class.perform_now

      aggregate_failures do
        single_region_ciphertext_profiles.each do |profile|
          expect(profile.reload.encrypted_pii_multi_region).to_not be_blank
          expect(profile.encrypted_pii_recovery_multi_region).to_not be_blank
        end
      end
    end
  end

  describe '#find_profiles_to_migrate' do
    it 'returns the profiles that need to be migrated' do
      results = subject.find_profiles_to_migrate(statement_timeout: 120, profile_count: 2)

      expect(results).to match_array(single_region_ciphertext_profiles)
    end
  end
end
