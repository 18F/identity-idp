require 'rails_helper'

RSpec.describe AccountRecovery::EligibilityPolicy do
  subject(:policy) { described_class.new(user: user) }

  let(:user) { create(:user, :fully_registered) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
  end

  describe '#recovery_pending?' do
    it 'finds an existing request when new recovery is disabled' do
      create(:account_recovery_request, :waiting, user: user)
      allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

      expect(policy.recovery_pending?).to eq(true)
    end

    it 'ignores terminal requests' do
      create(:account_recovery_request, :cancelled, user: user)

      expect(policy.recovery_pending?).to eq(false)
    end

    it 'does not query for an anonymous user' do
      expect(described_class.new(user: AnonymousUser.new).recovery_pending?).to eq(false)
    end
  end

  describe '#legacy_reset_allowed?' do
    it 'blocks legacy reset for eligible users' do
      expect(policy.legacy_reset_allowed?).to eq(false)
    end

    context 'with the feature disabled' do
      before do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
      end

      it 'allows legacy reset' do
        expect(policy.legacy_reset_allowed?).to eq(true)
      end

      it 'still blocks legacy reset for an active recovery request' do
        create(:account_recovery_request, :waiting, user: user)

        expect(policy.legacy_reset_allowed?).to eq(false)
      end
    end

    context 'for an identity-proofed user' do
      let(:user) { create(:user, :proofed) }

      it 'allows legacy reset' do
        expect(policy.legacy_reset_allowed?).to eq(true)
      end
    end

    context 'for a pending-profile user' do
      let(:user) { create(:user, :fully_registered, :with_pending_gpo_profile) }

      it 'allows legacy reset' do
        expect(policy.legacy_reset_allowed?).to eq(true)
      end
    end

    it 'blocks legacy reset when an active recovery request makes the user ineligible' do
      create(:account_recovery_request, :waiting, user: user)

      expect(policy.legacy_reset_allowed?).to eq(false)
    end

    it 'preserves an existing legacy request' do
      DestructiveAccountResetRequest.create!(
        user: user, request_token: SecureRandom.uuid, requested_at: Time.zone.now,
      )

      expect(policy.legacy_reset_allowed?).to eq(true)
    end
  end

  describe '#eligible?' do
    it 'is eligible for a fully registered, non-proofed user' do
      expect(policy.eligible?).to eq(true)
    end

    context 'when there is no user' do
      let(:user) { nil }

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user is anonymous' do
      let(:user) { AnonymousUser.new }

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the feature is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
      end

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user is not fully registered' do
      let(:user) { create(:user, :with_phone) }

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user has no MFA configured' do
      let(:user) { create(:user) }

      before do
        user.create_registration_log(registered_at: Time.zone.now)
      end

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user is identity proofed' do
      let(:user) { create(:user, :proofed) }

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user has a pending profile' do
      let(:user) { create(:user, :fully_registered, :with_pending_gpo_profile) }

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user has a password reset profile' do
      let(:user) { create(:user, :deactivated_password_reset_profile) }

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user is suspended' do
      let(:user) { create(:user, :fully_registered, :suspended) }

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user is fraud review pending' do
      let(:user) { create(:user, :fraud_review_pending) }

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user has no confirmed email address' do
      before do
        allow(user).to receive(:confirmed_email_addresses).and_return(EmailAddress.none)
      end

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user already has an active recovery request' do
      before do
        create(:account_recovery_request, :waiting, user: user)
      end

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when the user already has a pending legacy account reset request' do
      before do
        DestructiveAccountResetRequest.create!(
          user: user,
          request_token: SecureRandom.uuid,
          requested_at: Time.zone.now,
        )
      end

      it 'is ineligible' do
        expect(policy.eligible?).to eq(false)
      end
    end

    context 'when a terminal recovery request exists' do
      before do
        create(:account_recovery_request, :cancelled, user: user)
      end

      it 'is still eligible' do
        expect(policy.eligible?).to eq(true)
      end
    end

    context 'with a legacy request past its waiting period' do
      let!(:legacy_request) do
        DestructiveAccountResetRequest.create!(
          user: user,
          request_token: SecureRandom.uuid,
          requested_at: 10.days.ago,
        )
      end

      it 'keeps the request in the legacy flow while waiting for the grant job' do
        expect(policy.eligible?).to eq(false)
        expect(policy.legacy_reset_allowed?).to eq(true)
      end

      it 'keeps a usable granted deletion link in the legacy flow' do
        legacy_request.update!(granted_at: Time.zone.now, granted_token: SecureRandom.uuid)

        expect(policy.eligible?).to eq(false)
        expect(policy.legacy_reset_allowed?).to eq(true)
      end

      it 'allows new recovery after the legacy request is cancelled' do
        legacy_request.update!(cancelled_at: Time.zone.now)

        expect(policy.eligible?).to eq(true)
      end

      it 'allows new recovery after the legacy granted token expires' do
        legacy_request.update!(
          granted_at: (IdentityConfig.store.account_reset_token_valid_for_days + 1).days.ago,
          granted_token: SecureRandom.uuid,
        )

        expect(policy.eligible?).to eq(true)
      end
    end

    context 'when an eligibility input cannot be read' do
      before do
        allow(user).to receive(:active_profile?).and_raise(ActiveRecord::StatementInvalid)
      end

      it 'propagates the error rather than reporting ordinary ineligibility' do
        expect { policy.eligible? }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
    # Re-checking eligibility for an in-flight request must not treat that
    # request as a competing pending request.
    context 'with ignore_pending_request' do
      let!(:recovery_request) { create(:account_recovery_request, :waiting, user: user) }

      subject(:policy) do
        described_class.new(user: user, ignore_pending_request: recovery_request)
      end

      it 'ignores the named request' do
        expect(policy.eligible?).to eq(true)
      end

      it 'still rejects a pending legacy account reset request' do
        DestructiveAccountResetRequest.create!(
          user: user,
          request_token: SecureRandom.uuid,
          requested_at: Time.zone.now,
        )

        expect(policy.eligible?).to eq(false)
      end

      it 'still applies the other eligibility rules' do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

        expect(policy.eligible?).to eq(false)
      end
    end
  end
end
