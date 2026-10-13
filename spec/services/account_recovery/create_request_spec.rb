require 'rails_helper'

RSpec.describe AccountRecovery::CreateRequest do
  subject(:service) do
    described_class.new(user: user, requesting_issuer: requesting_issuer, bucket: bucket)
  end

  let(:user) { create(:user, :fully_registered) }
  let(:requesting_issuer) { nil }
  let(:bucket) { :account_preserving }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
  end

  describe '#call' do
    it 'creates a waiting request for an eligible user' do
      result = service.call

      expect(result.success?).to eq(true)

      request = AccountRecoveryRequest.active_for_user(user)
      expect(request).to be_present
      expect(request.state).to eq(AccountRecoveryRequest::WAITING)
      expect(request.flow_variant)
        .to eq(AccountRecoveryRequest::FLOW_VARIANT_ACCOUNT_PRESERVING)
      expect(request.requested_at).to be_present
    end

    it 'exposes the created request' do
      service.call

      expect(service.account_recovery_request).to eq(AccountRecoveryRequest.active_for_user(user))
    end

    it 'returns bounded, non-sensitive analytics attributes' do
      result = service.call

      expect(result.to_h).to include(
        success: true,
        eligibility_reason: AccountRecovery::EligibilityPolicy::ELIGIBLE,
        flow_variant: AccountRecoveryRequest::FLOW_VARIANT_ACCOUNT_PRESERVING,
        recovery_state: AccountRecoveryRequest::WAITING,
      )
    end

    it 'does not issue a recovery token in phase 1' do
      service.call

      request = AccountRecoveryRequest.active_for_user(user)
      expect(request.token_fingerprint).to be_nil
      expect(request.token_expires_at).to be_nil
      expect(request.granted_at).to be_nil
    end

    it 'does not mutate any MFA configuration' do
      phone_count = user.phone_configurations.count

      service.call

      expect(user.reload.phone_configurations.count).to eq(phone_count)
    end

    context 'with a requesting service provider' do
      let(:service_provider) { create(:service_provider) }
      let(:requesting_issuer) { service_provider.issuer }

      it 'records the issuer' do
        service.call

        expect(AccountRecoveryRequest.active_for_user(user).requesting_issuer)
          .to eq(requesting_issuer)
      end
    end

    context 'when the user is ineligible' do
      let(:bucket) { :legacy }

      it 'fails without creating a request' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(result.to_h[:eligibility_reason])
          .to eq(AccountRecovery::EligibilityPolicy::CONTROL_BUCKET)
        expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
      end
    end

    context 'when the feature is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)
      end

      it 'fails without creating a request' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
      end
    end

    context 'when the user already has an active recovery request' do
      let!(:existing_request) { create(:account_recovery_request, :waiting, user: user) }

      it 'is rejected by eligibility rather than superseding silently' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(result.to_h[:eligibility_reason])
          .to eq(AccountRecovery::EligibilityPolicy::EXISTING_REQUEST_PENDING)
        expect(existing_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
      end
    end

    context 'when the user has a pending legacy account reset request' do
      before do
        AccountResetRequest.create!(
          user: user,
          request_token: SecureRandom.uuid,
          requested_at: Time.zone.now,
        )
      end

      it 'is rejected by eligibility' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(result.to_h[:eligibility_reason])
          .to eq(AccountRecovery::EligibilityPolicy::EXISTING_REQUEST_PENDING)
      end
    end

    context 'when a prior recovery request is terminal' do
      before do
        create(:account_recovery_request, :cancelled, user: user)
      end

      it 'creates a new request and leaves the terminal one alone' do
        result = service.call

        expect(result.success?).to eq(true)
        expect(AccountRecoveryRequest.where(user: user).count).to eq(2)
        expect(AccountRecoveryRequest.active.where(user: user).count).to eq(1)
      end
    end

    context 'when the record cannot reach the waiting state' do
      before do
        allow_any_instance_of(AccountRecoveryRequest).to receive(:wait!).and_return(false)
      end

      it 'fails closed and leaves no stranded row behind' do
        result = service.call

        expect(result.success?).to eq(false)
        expect(result.to_h[:eligibility_reason]).to eq(described_class::REQUEST_NOT_PERSISTED)
        expect(AccountRecoveryRequest.where(user: user).count).to eq(0)
      end
    end
  end
end
