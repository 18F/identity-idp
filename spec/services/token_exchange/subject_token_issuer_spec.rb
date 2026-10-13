require 'rails_helper'

RSpec.describe TokenExchange::SubjectTokenIssuer do
  describe '.issue' do
    subject(:issued_token) { described_class.issue(identity:) }

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
        user_id: identity.user_id,
        identity_uuid: identity.uuid,
        broker_issuer: identity.service_provider,
        scope: 'openid token_exchange:passport',
        ial: 2,
      )
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
