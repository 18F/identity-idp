require 'rails_helper'

RSpec.describe TokenExchange::AccessTokenIssuer do
  describe '.issue' do
    subject(:issued_token) do
      described_class.issue(
        subject_token:,
        target_issuer:,
        resource:,
        scope:,
      )
    end

    let(:subject_token) do
      TokenExchange::SubjectToken.new(
        id: 'subject-token-digest',
        identity_uuid: 'identity-uuid',
        broker_issuer: 'broker-issuer',
        scope: 'openid token_exchange:passport',
        ial: 2,
        issued_at: Time.zone.now.to_i,
      )
    end
    let(:target_issuer) { 'target-issuer' }
    let(:resource) { 'https://api.example.gov/passport' }
    let(:scope) { 'openid token_exchange:passport' }

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_access_token_expires_in)
        .and_return(600)
    end

    it 'returns an opaque token' do
      expect(issued_token.token).to be_present
      expect(issued_token.token).to be_a(String)
    end

    it 'returns the configured expiration' do
      expect(issued_token.expires_in).to eq(600)
    end

    it 'stores delegated access token metadata in Redis by token digest' do
      loaded_access_token = TokenExchange::AccessToken.load(issued_token.token)

      expect(loaded_access_token).to have_attributes(
        identity_uuid: 'identity-uuid',
        broker_issuer: 'broker-issuer',
        target_issuer: 'target-issuer',
        resource: 'https://api.example.gov/passport',
        scope: 'openid token_exchange:passport',
        expires_at: loaded_access_token.issued_at + 600,
      )
    end

    it 'stores the token with the configured expiration' do
      expect(EncryptedRedisStructStorage).to receive(:store).with(
        instance_of(TokenExchange::AccessToken),
        expires_in: 600,
      )

      issued_token
    end
  end
end
