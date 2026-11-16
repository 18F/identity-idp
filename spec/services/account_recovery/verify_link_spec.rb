require 'rails_helper'

RSpec.describe AccountRecovery::VerifyLink do
  subject(:service) { described_class.new(token: raw_token) }

  let(:user) { create(:user, :fully_registered) }
  let(:raw_token) { SecureRandom.uuid }
  let!(:recovery_request) do
    create(
      :account_recovery_request,
      :granted,
      user: user,
      token_fingerprint: AccountRecovery::TokenCreator.fingerprint(raw_token),
    )
  end

  describe '#call' do
    it 'marks a granted request as link verified without consuming the token' do
      result = service.call

      expect(result).to be_success
      expect(result.to_h).to eq(success: true, recovery_state: AccountRecoveryRequest::GRANTED)
      expect(service.account_recovery_request).to eq(recovery_request)

      recovery_request.reload
      expect(recovery_request.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
      expect(recovery_request.link_verified_at).to be_present
      expect(recovery_request).to be_token_valid
    end

    it 'accepts a reopened link without changing the verification timestamp' do
      service.call
      verified_at = recovery_request.reload.link_verified_at

      result = described_class.new(token: raw_token).call

      expect(result).to be_success
      expect(result.to_h[:recovery_state]).to eq(AccountRecoveryRequest::LINK_VERIFIED)
      expect(recovery_request.reload.link_verified_at).to eq(verified_at)
    end

    it 'rejects a blank token' do
      result = described_class.new(token: nil).call

      expect(result).not_to be_success
      expect(result.to_h[:failure_reason]).to eq('token_missing')
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
    end

    it 'rejects an unknown token without changing the request' do
      result = described_class.new(token: SecureRandom.uuid).call

      expect(result).not_to be_success
      expect(result.to_h[:failure_reason]).to eq('token_invalid')
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
    end

    it 'rejects an expired token' do
      recovery_request.update!(token_expires_at: Time.zone.now - 1.minute)

      result = service.call

      expect(result).not_to be_success
      expect(result.to_h[:failure_reason]).to eq('token_expired')
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
    end

    it 'rejects a request whose password was already verified' do
      recovery_request.update!(state: AccountRecoveryRequest::PASSWORD_VERIFIED)

      result = service.call

      expect(result).not_to be_success
      expect(result.to_h[:failure_reason]).to eq('wrong_state')
    end

    it 'rejects a token belonging to a cancelled request' do
      recovery_request.update!(
        state: AccountRecoveryRequest::CANCELLED,
        cancelled_at: Time.zone.now,
      )

      result = service.call

      expect(result).not_to be_success
      expect(result.to_h[:failure_reason]).to eq('token_invalid')
    end

    it 'rejects a token belonging to an expired request' do
      recovery_request.update!(state: AccountRecoveryRequest::EXPIRED, expired_at: Time.zone.now)

      result = service.call

      expect(result).not_to be_success
      expect(result.to_h[:failure_reason]).to eq('token_invalid')
    end

    it 'rejects a request cancelled after the token was validated' do
      raced = false
      allow_any_instance_of(AccountRecoveryRequest).to receive(:lock!)
        .and_wrap_original do |m, *args|
        unless raced
          raced = true
          AccountRecoveryRequest.find(recovery_request.id)
            .cancel!(reason: AccountRecoveryRequest::CANCEL_REASON_MFA_USED)
        end
        m.call(*args)
      end

      result = service.call

      expect(result).not_to be_success
      expect(result.to_h[:failure_reason]).to eq('transition_failed')
      expect(service.account_recovery_request).to be_nil
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::CANCELLED)
    end

    it 'does not include the raw token in analytics output' do
      result = service.call

      expect(result.to_h.values.map(&:to_s)).not_to include(raw_token)
    end
  end
end
