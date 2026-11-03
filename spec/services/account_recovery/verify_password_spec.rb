require 'rails_helper'

RSpec.describe AccountRecovery::VerifyPassword do
  subject(:service) do
    described_class.new(account_recovery_request: recovery_request, password: password)
  end

  let(:password) { 'salty pickles' }
  let(:user) { create(:user, :fully_registered, password: password) }
  let!(:recovery_request) { create(:account_recovery_request, :link_verified, user: user) }

  describe '#call' do
    it 'consumes the token once the password is correct' do
      result = service.call

      expect(result).to be_success
      expect(result.to_h).to eq(
        success: true,
        recovery_state: AccountRecoveryRequest::PASSWORD_VERIFIED,
      )

      recovery_request.reload
      expect(recovery_request.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
      expect(recovery_request.password_verified_at).to be_present
      expect(recovery_request.token_fingerprint).to be_nil
      expect(recovery_request.token_expires_at).to be_nil
    end

    it 'does not change existing MFA methods' do
      expect { service.call }.not_to change { user.reload.phone_configurations.count }
    end

    context 'with an incorrect password' do
      let(:service) do
        described_class.new(
          account_recovery_request: recovery_request,
          password: 'not the right password',
        )
      end

      it 'reports a password error and leaves the token valid for retry' do
        result = service.call

        expect(result).not_to be_success
        expect(result.errors).to eq(password: ['incorrect_password'])
        expect(result.to_h[:failure_reason]).to eq('incorrect_password')

        recovery_request.reload
        expect(recovery_request.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
        expect(recovery_request.password_verified_at).to be_nil
        expect(recovery_request).to be_token_valid
      end

      it 'does not include the password in analytics output' do
        expect(service.call.to_h.values.map(&:to_s)).not_to include('not the right password')
      end
    end

    it 'does not consume the token for a blank password' do
      result = described_class.new(account_recovery_request: recovery_request, password: '').call

      expect(result).not_to be_success
      expect(result.errors).to eq(password: ['incorrect_password'])
      expect(recovery_request.reload).to be_token_valid
    end

    it 'rejects a token that expired before the password was checked' do
      recovery_request.update!(token_expires_at: Time.zone.now)

      result = service.call

      expect(result).not_to be_success
      expect(result.errors).to eq(base: ['token_invalid'])
      expect(recovery_request.reload.password_verified_at).to be_nil
    end

    it 'rejects a request that is no longer link verified' do
      recovery_request.cancel!(reason: AccountRecoveryRequest::CANCEL_REASON_USER_CANCELLED)

      result = service.call

      expect(result).not_to be_success
      expect(result.errors).to eq(base: ['token_invalid'])
    end

    it 'rejects a concurrent submit that consumed the token during the password check' do
      allow(user).to receive(:valid_password?) do
        AccountRecoveryRequest.find(recovery_request.id).transition_to!(
          AccountRecoveryRequest::PASSWORD_VERIFIED,
          token_fingerprint: nil,
          token_expires_at: nil,
        )
        true
      end
      allow(recovery_request).to receive(:user).and_return(user)

      result = service.call

      expect(result).not_to be_success
      expect(result.errors).to eq(base: ['token_invalid'])
    end

    it 'rejects replay after the token has been consumed' do
      service.call

      result = described_class.new(
        account_recovery_request: recovery_request,
        password: password,
      ).call

      expect(result).not_to be_success
      expect(result.errors).to eq(base: ['token_invalid'])
    end
  end
end
