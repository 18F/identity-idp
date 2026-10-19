require 'rails_helper'

RSpec.describe AccountRecovery::ValidateGrantedToken do
  let(:user) { create(:user, :fully_registered) }
  let(:raw_token) { SecureRandom.uuid }

  def create_granted_request(token: raw_token, **attributes)
    create(
      :account_recovery_request,
      :granted,
      user: user,
      token_fingerprint: AccountRecovery::TokenCreator.fingerprint(token),
      **attributes,
    )
  end

  describe '#call' do
    it 'accepts a token matching an active granted request' do
      recovery_request = create_granted_request

      validator = described_class.new(token: raw_token)
      result = validator.call

      expect(result).to be_success
      expect(validator.account_recovery_request).to eq(recovery_request)
    end

    it 'rejects a blank token' do
      result = described_class.new(token: nil).call

      expect(result).to_not be_success
      expect(result.to_h[:failure_reason]).to eq('token_missing')
    end

    it 'rejects an unknown token' do
      create_granted_request

      result = described_class.new(token: SecureRandom.uuid).call

      expect(result).to_not be_success
      expect(result.to_h[:failure_reason]).to eq('token_invalid')
    end

    it 'rejects an expired token' do
      create_granted_request(token_expires_at: Time.zone.now - 1.minute)

      result = described_class.new(token: raw_token).call

      expect(result).to_not be_success
      expect(result.to_h[:failure_reason]).to eq('token_expired')
    end

    it 'accepts a verified link until password verification consumes it' do
      create_granted_request(state: AccountRecoveryRequest::LINK_VERIFIED)

      expect(described_class.new(token: raw_token).call).to be_success
    end

    it 'rejects an expired verified link' do
      create_granted_request(
        state: AccountRecoveryRequest::LINK_VERIFIED,
        token_expires_at: Time.zone.now,
      )

      expect(described_class.new(token: raw_token).call).not_to be_success
    end

    it 'rejects a request whose password was already verified' do
      create_granted_request(state: AccountRecoveryRequest::PASSWORD_VERIFIED)

      result = described_class.new(token: raw_token).call

      expect(result).to_not be_success
      expect(result.to_h[:failure_reason]).to eq('wrong_state')
    end

    it 'rejects a token belonging to a cancelled request' do
      create_granted_request(
        state: AccountRecoveryRequest::CANCELLED,
        cancelled_at: Time.zone.now,
      )

      result = described_class.new(token: raw_token).call

      expect(result).to_not be_success
      expect(result.to_h[:failure_reason]).to eq('token_invalid')
    end

    it 'rejects a token belonging to an expired request' do
      create_granted_request(
        state: AccountRecoveryRequest::EXPIRED,
        expired_at: Time.zone.now,
      )

      result = described_class.new(token: raw_token).call

      expect(result).to_not be_success
      expect(result.to_h[:failure_reason]).to eq('token_invalid')
    end

    it 'does not include the raw token in analytics output' do
      create_granted_request

      result = described_class.new(token: raw_token).call

      expect(result.to_h.values.map(&:to_s)).to_not include(raw_token)
    end
  end
end
