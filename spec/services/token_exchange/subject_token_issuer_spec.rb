require 'rails_helper'

RSpec.describe TokenExchange::SubjectTokenIssuer do
  describe '.issue' do
    subject(:issued_token) { described_class.issue(identity:, actor_return_log_id: 123) }

    let(:user) { create(:user) }
    let(:identity) do
      create(
        :service_provider_identity,
        user:,
        scope: 'openid token_exchange:passport',
        ial: 2,
      )
    end

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_subject_token_expires_in)
        .and_return(600)
    end

    it 'returns an opaque token' do
      expect(issued_token.token).to be_present
      expect(issued_token.token).to be_a(String)
    end

    it 'stores the subject token metadata in Redis by token digest' do
      loaded_subject_token = TokenExchange::SubjectToken.load(issued_token.token)

      expect(loaded_subject_token).to have_attributes(
        identity_uuid: identity.uuid,
        broker_issuer: identity.service_provider,
        scope: 'openid token_exchange:passport',
        ial: 2,
        actor_return_log_id: 123,
      )
    end

    context 'with a key thumbprint' do
      subject(:issued_token) { described_class.issue(identity:, dpop_jkt: 'a' * 43) }

      it 'stores the thumbprint the subject token is bound to' do
        expect(TokenExchange::SubjectToken.load(issued_token.token).dpop_jkt).to eq('a' * 43)
      end
    end

    it 'does not store the user database identifier' do
      loaded_subject_token = TokenExchange::SubjectToken.load(issued_token.token)

      expect(loaded_subject_token.to_h.keys).to_not include(:user_id)
    end

    it 'stores the token with the configured expiration' do
      expect(EncryptedRedisStructStorage).to receive(:store).with(
        instance_of(TokenExchange::SubjectToken),
        expires_in: 600,
      )

      issued_token
    end
  end
end
