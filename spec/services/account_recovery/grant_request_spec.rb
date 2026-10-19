require 'rails_helper'

RSpec.describe AccountRecovery::GrantRequest do
  let(:user) { create(:user, :fully_registered) }
  let(:recovery_request) { create(:account_recovery_request, :waiting, user: user) }

  subject(:service) { described_class.new(account_recovery_request: recovery_request) }

  before do
    allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:account_recovery_token_valid_for_hours).and_return(24)
  end

  describe '#call' do
    it 'moves the request to granted' do
      expect(service.call).to be_success

      recovery_request.reload
      expect(recovery_request.state).to eq(AccountRecoveryRequest::GRANTED)
      expect(recovery_request.granted_at).to be_present
    end

    it 'returns the raw recovery token which is not persisted' do
      result = service.call

      expect(result.token.raw).to be_present

      recovery_request.reload
      expect(recovery_request.token_fingerprint).to eq(
        AccountRecovery::TokenCreator.fingerprint(result.token.raw),
      )
      expect(recovery_request.attributes.values.map(&:to_s)).to_not include(result.token.raw)
    end

    it 'sets token expiration from configuration' do
      allow(IdentityConfig.store).to receive(:account_recovery_token_valid_for_hours).and_return(6)

      freeze_time do
        service.call

        expect(recovery_request.reload.token_expires_at).to eq(Time.zone.now + 6.hours)
      end
    end

    it 'fails when the request is not waiting' do
      recovery_request.update!(state: AccountRecoveryRequest::GRANTED)

      result = service.call

      expect(result).to_not be_success
      expect(result.failure_reason).to eq(described_class::NOT_WAITING)
    end

    it 'does not regrant or cancel a request advanced by another worker' do
      stale_request = AccountRecoveryRequest.find(recovery_request.id)
      expect(service.call).to be_success
      granted_attributes = recovery_request.reload.attributes
      allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

      result = described_class.new(account_recovery_request: stale_request).call

      expect(result).not_to be_success
      expect(result.failure_reason).to eq(described_class::NOT_WAITING)
      expect(result.token).to be_nil
      expect(stale_request.reload.attributes).to eq(granted_attributes)
    end

    context 'when the user became ineligible during the waiting period' do
      it 'cancels the request rather than granting it' do
        create(:profile, :active, user: user)

        result = service.call

        expect(result).to_not be_success
        expect(result.failure_reason).to eq(described_class::INELIGIBLE)

        recovery_request.reload
        expect(recovery_request.state).to eq(AccountRecoveryRequest::CANCELLED)
        expect(recovery_request.token_fingerprint).to be_nil
      end

      it 'cancels when the feature is turned off mid-flight' do
        allow(IdentityConfig.store).to receive(:account_recovery_v2_enabled).and_return(false)

        expect(service.call).to_not be_success
        expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
      end

      it 'cancels when the user is suspended' do
        user.update!(suspended_at: Time.zone.now, reinstated_at: nil)

        expect(service.call).to_not be_success
        expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
      end
    end

    # The request being granted is itself active, so it must not count as a
    # competing pending request during the eligibility re-check.
    it 'does not treat its own request as a blocking pending request' do
      expect(service.call).to be_success
    end
  end
end
