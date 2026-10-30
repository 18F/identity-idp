require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PersonalKeyPolicy do
  let(:subject) { described_class.new(user) }

  describe '#configured?' do
    context 'without a personal key' do
      let(:user) { build(:user) }

      it { expect(subject.configured?).to be_falsey }
    end

    context 'with a personal key' do
      let(:user) { create(:user, :with_personal_key) }

      it { expect(subject.configured?).to be_truthy }
    end
  end

  describe '#enabled?' do
    context 'without a personal key' do
      let(:user) { build(:user) }

      it { expect(subject.enabled?).to be_falsey }
    end

    context 'with a personal key and no profile' do
      let(:user) { create(:user, :with_personal_key) }

      it { expect(subject.enabled?).to be_truthy }
    end

    context 'with a personal key and an identity-verified profile' do
      let(:user) do
        profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
        PersonalKeyGenerator.new(profile.user).generate!
        profile.user
      end

      it 'is false because the key belongs to the profile, not an MFA method' do
        expect(subject.enabled?).to be_falsey
      end
    end
  end

  describe '#mfa_deprecated?' do
    context 'when personal key MFA deprecation phase 1 is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:personal_key_mfa_deprecation_phase_1_enabled)
          .and_return(false)
      end

      context 'with a personal key MFA user who has another MFA method' do
        let(:user) { create(:user, :with_phone, :with_personal_key) }

        it { expect(subject.mfa_deprecated?).to be_falsey }
      end
    end

    context 'when personal key MFA deprecation phase 1 is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:personal_key_mfa_deprecation_phase_1_enabled)
          .and_return(true)
      end

      context 'with a personal key MFA user who has another MFA method' do
        let(:user) { create(:user, :with_phone, :with_personal_key) }

        it { expect(subject.mfa_deprecated?).to be_truthy }
      end

      context 'with a user who has no personal key' do
        let(:user) { create(:user, :with_phone) }

        it { expect(subject.mfa_deprecated?).to be_falsey }
      end

      context 'with a personal-key-only user (no other MFA method)' do
        let(:user) { create(:user, :with_personal_key) }

        it 'is false so the deprecation never leaves the account without a credential' do
          expect(subject.mfa_deprecated?).to be_falsey
        end
      end

      context 'with an identity-verified user who has a personal key' do
        let(:user) do
          profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
          verified_user = profile.user
          PersonalKeyGenerator.new(verified_user).generate!
          create(:phone_configuration, user: verified_user)
          verified_user
        end

        it 'is false because the key is used for account recovery/IDV, not MFA' do
          expect(subject.mfa_deprecated?).to be_falsey
        end
      end
    end
  end

  describe '#mfa_required?' do
    context 'when personal key MFA deprecation phase 1 is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:personal_key_mfa_deprecation_phase_1_enabled)
          .and_return(false)
      end

      context 'with a personal-key-only user' do
        let(:user) { create(:user, :with_personal_key) }

        it { expect(subject.mfa_required?).to be_falsey }
      end
    end

    context 'when personal key MFA deprecation phase 1 is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:personal_key_mfa_deprecation_phase_1_enabled)
          .and_return(true)
      end

      context 'with a personal-key-only user (no other MFA method)' do
        let(:user) { create(:user, :with_personal_key) }

        it 'is true so the user must authenticate with their personal key' do
          expect(subject.mfa_required?).to be_truthy
        end
      end

      context 'with a personal key MFA user who has another MFA method' do
        let(:user) { create(:user, :with_phone, :with_personal_key) }

        it 'is false because the other MFA method is used to authenticate instead' do
          expect(subject.mfa_required?).to be_falsey
        end
      end

      context 'with a user who has no personal key' do
        let(:user) { create(:user, :with_phone) }

        it { expect(subject.mfa_required?).to be_falsey }
      end

      context 'with an identity-verified user who has a personal key' do
        let(:user) do
          profile = create(:profile, :active, :verified, pii: { ssn: '1234' })
          verified_user = profile.user
          PersonalKeyGenerator.new(verified_user).generate!
          verified_user
        end

        it 'is false because the key is used for account recovery/IDV, not MFA' do
          expect(subject.mfa_required?).to be_falsey
        end
      end
    end
  end
end
