require 'rails_helper'

RSpec.describe AccountRecovery::EligibilityPolicy do
  subject(:policy) { described_class.new(user: user) }

  let(:user) { create(:user, :fully_registered) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
  end

  describe '#call' do
    it 'is eligible for a fully registered, non-proofed user' do
      result = policy.call

      expect(result.eligible?).to eq(true)
      expect(result.reason).to eq(described_class::ELIGIBLE)
    end

    context 'when there is no user' do
      let(:user) { nil }

      it 'is ineligible' do
        result = policy.call

        expect(result.eligible?).to eq(false)
        expect(result.reason).to eq(described_class::NO_USER)
      end
    end

    context 'when the user is anonymous' do
      let(:user) { AnonymousUser.new }

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::NO_USER)
      end
    end

    context 'when the feature is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
      end

      it 'is ineligible' do
        result = policy.call

        expect(result.eligible?).to eq(false)
        expect(result.reason).to eq(described_class::FEATURE_DISABLED)
      end
    end

    context 'when the user is not fully registered' do
      let(:user) { create(:user, :with_phone) }

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::NOT_FULLY_REGISTERED)
      end
    end

    context 'when the user has no MFA configured' do
      let(:user) { create(:user) }

      before do
        user.create_registration_log(registered_at: Time.zone.now)
      end

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::NO_MFA_CONFIGURED)
      end
    end

    context 'when the user is identity proofed' do
      let(:user) { create(:user, :proofed) }

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::IDENTITY_VERIFIED)
      end
    end

    context 'when the user has a pending profile' do
      let(:user) { create(:user, :fully_registered, :with_pending_gpo_profile) }

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::PENDING_PROFILE)
      end
    end

    context 'when the user has a password reset profile' do
      let(:user) { create(:user, :deactivated_password_reset_profile) }

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::PASSWORD_RESET_PROFILE)
      end
    end

    context 'when the user is suspended' do
      let(:user) { create(:user, :fully_registered, :suspended) }

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::ACCOUNT_SUSPENDED)
      end
    end

    context 'when the user is fraud review pending' do
      let(:user) { create(:user, :fraud_review_pending) }

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::PENDING_PROFILE)
      end
    end

    context 'when the user has no confirmed email address' do
      before do
        allow(user).to receive(:confirmed_email_addresses).and_return(EmailAddress.none)
      end

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::NO_CONFIRMED_EMAIL)
      end
    end

    context 'when the user already has an active recovery request' do
      before do
        create(:account_recovery_request, :waiting, user: user)
      end

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::EXISTING_REQUEST_PENDING)
      end
    end

    context 'when the user already has a pending legacy account reset request' do
      before do
        AccountResetRequest.create!(
          user: user,
          request_token: SecureRandom.uuid,
          requested_at: Time.zone.now,
        )
      end

      it 'is ineligible' do
        expect(policy.call.reason).to eq(described_class::EXISTING_REQUEST_PENDING)
      end
    end

    context 'when a terminal recovery request exists' do
      before do
        create(:account_recovery_request, :cancelled, user: user)
      end

      it 'is still eligible' do
        expect(policy.call.eligible?).to eq(true)
      end
    end

    context 'when an eligibility input cannot be read' do
      before do
        allow(user).to receive(:active_profile?).and_raise(ActiveRecord::StatementInvalid)
      end

      it 'propagates the error rather than reporting ordinary ineligibility' do
        expect { policy.call }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end

  describe '#eligible?' do
    it 'mirrors the result of #call' do
      expect(policy.eligible?).to eq(policy.call.eligible?)
    end
  end
end
