require 'rails_helper'
require 'rake'

RSpec.describe 'backfill profiles tasks' do
  let(:profile_limit) { '10' }
  let(:update_profiles) { nil }
  let(:env) do
    {
      'PROFILE_LIMIT' => profile_limit,
      'STATEMENT_TIMEOUT_SECONDS' => '100',
      'UPDATE_PROFILES' => update_profiles,
    }
  end

  before do
    Rake.application.rake_require 'tasks/backfill_profiles'
    Rake::Task.define_task(:environment)
    Rake::Task['profiles:backfill_encrypted_pii_multi_region'].reenable
    stub_const('ENV', env)
  end

  describe 'dev:backfill_encrypted_pii_multi_region' do
    it 'logs data about profiles being migrated' do
      profile = create_profile_that_needs_to_be_migrated
      create(:profile, :with_pii)

      expect(Rails.logger).to receive(:info).with('1 profiles found')
      expect(Rails.logger).to receive(:info).with(profile.id)

      Rake::Task['profiles:backfill_encrypted_pii_multi_region'].invoke
    end

    context 'with update_profiles disabled' do
      it 'does not update profiles' do
        profile = create_profile_that_needs_to_be_migrated

        expect(profile.encrypted_pii).to be_present
        expect(profile.encrypted_pii_recovery).to be_present
        expect(profile.encrypted_pii_multi_region).to_not be_present
        expect(profile.encrypted_pii_recovery_multi_region).to_not be_present

        Rake::Task['profiles:backfill_encrypted_pii_multi_region'].invoke

        expect(profile.encrypted_pii).to be_present
        expect(profile.encrypted_pii_recovery).to be_present
        expect(profile.encrypted_pii_multi_region).to_not be_present
        expect(profile.encrypted_pii_recovery_multi_region).to_not be_present
      end
    end

    context 'with update_profiles enabled' do
      let(:update_profiles) { 'true' }

      it 'does update profiles' do
        profile = create_profile_that_needs_to_be_migrated
        expect(profile.encrypted_pii).to be_present
        expect(profile.encrypted_pii_recovery).to be_present
        expect(profile.encrypted_pii_multi_region).to_not be_present
        expect(profile.encrypted_pii_recovery_multi_region).to_not be_present

        Rake::Task['profiles:backfill_encrypted_pii_multi_region'].invoke

        profile.reload
        expect(profile.encrypted_pii).to be_present
        expect(profile.encrypted_pii_recovery).to be_present
        expect(profile.encrypted_pii_multi_region).to be_present
        expect(profile.encrypted_pii_recovery_multi_region).to be_present
      end
    end
  end

  def create_profile_that_needs_to_be_migrated
    profile = create(:profile, :with_pii)
    profile.update(
      encrypted_pii: profile.encrypted_pii_multi_region,
      encrypted_pii_multi_region: nil,
      encrypted_pii_recovery: profile.encrypted_pii_recovery_multi_region,
      encrypted_pii_recovery_multi_region: nil,
    )
    profile
  end
end
