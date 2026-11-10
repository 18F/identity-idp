require 'rails_helper'

RSpec.describe AccountRecovery::ReconcileRequest do
  let(:user) { create(:user, :fully_registered) }

  describe '#call' do
    it 'expires a granted request whose link has lapsed' do
      recovery_request = create(
        :account_recovery_request,
        :granted,
        user: user,
        token_expires_at: Time.zone.now - 1.minute,
      )

      expect(described_class.new(account_recovery_request: recovery_request).call).to eq(true)

      recovery_request.reload
      expect(recovery_request.state).to eq(AccountRecoveryRequest::EXPIRED)
      expect(recovery_request.failure_reason).to eq('token_not_redeemed')
      expect(recovery_request.token_fingerprint).to be_nil
    end

    it 'leaves a granted request whose link is still valid' do
      recovery_request = create(
        :account_recovery_request,
        :granted,
        user: user,
        token_expires_at: Time.zone.now + 1.hour,
      )

      expect(described_class.new(account_recovery_request: recovery_request).call).to eq(false)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::GRANTED)
    end

    it 'expires a verified link if password verification was not completed' do
      recovery_request = create(
        :account_recovery_request,
        :link_verified,
        user: user,
        token_expires_at: Time.zone.now - 5.days,
      )

      expect(described_class.new(account_recovery_request: recovery_request).call).to eq(true)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::EXPIRED)
    end

    it 'never expires a password-verified request' do
      recovery_request = create(
        :account_recovery_request,
        :password_verified,
        user: user,
        token_expires_at: Time.zone.now - 5.days,
      )

      expect(described_class.new(account_recovery_request: recovery_request).call).to eq(false)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
    end

    it 'does not expire a request whose password was verified after loading it' do
      recovery_request = create(
        :account_recovery_request,
        :link_verified,
        user: user,
        token_expires_at: Time.zone.now - 1.minute,
      )
      AccountRecoveryRequest.find(recovery_request.id)
        .transition_to!(AccountRecoveryRequest::PASSWORD_VERIFIED)

      expect(described_class.new(account_recovery_request: recovery_request).call).to eq(false)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::PASSWORD_VERIFIED)
    end

    it 'leaves a waiting request alone' do
      recovery_request = create(:account_recovery_request, :waiting, user: user)

      expect(described_class.new(account_recovery_request: recovery_request).call).to eq(false)
      expect(recovery_request.reload.state).to eq(AccountRecoveryRequest::WAITING)
    end

    it 'handles a nil request' do
      expect(described_class.new(account_recovery_request: nil).call).to eq(false)
    end
  end
end
