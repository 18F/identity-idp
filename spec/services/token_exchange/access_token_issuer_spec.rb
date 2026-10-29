require 'rails_helper'

RSpec.describe TokenExchange::AccessTokenIssuer do
  describe '.issue' do
    subject(:subject) do
      described_class.issue(
        subject_token:,
        target_identity:,
        target_issuer:,
        resource:,
        scope:,
      )
    end

    let(:subject_token) do
      TokenExchange::SubjectToken.new(
        id: 'subject-token-digest',
        identity_uuid: broker_identity.uuid,
        broker_issuer:,
        scope:,
        ial: 2,
        actor_return_log_id: actor_return_log.id,
        issued_at: Time.zone.now.to_i,
      )
    end
    let(:user) { create(:user) }
    let!(:target) { create(:service_provider, :active, issuer: 'target-issuer') }
    let!(:broker) { create(:service_provider, :active, issuer: 'broker-issuer') }
    let(:target_issuer) { target.issuer }
    let(:broker_issuer) { broker.issuer }
    let(:target_private_key) do
      OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read)
    end
    let(:broker_identity) do
      create(:service_provider_identity, service_provider: broker_issuer, user:)
    end
    let(:actor_return_log) do
      create(:sp_return_log, user:, issuer: broker_issuer, ial: 2, billable: true)
    end

    let!(:target_identity) do
      create(:service_provider_identity, service_provider: target_issuer, user:)
    end
    let(:resource) { 'https://api.example.gov/passport' }
    let(:scope) { 'openid token_exchange:passport' }

    before do
      allow(IdentityConfig.store).to receive(:token_exchange_access_token_expires_in)
        .and_return(600)
    end

    it 'returns a signed JWE access token encrypted for the target' do
      jwt = JWE.decrypt(subject.token, target_private_key)
      payload = JWT.decode(
        jwt,
        Rails.application.config.oidc_public_key,
        true,
        algorithm: IdTokenBuilder::JWT_SIGNING_ALGORITHM,
      ).first

      expect(payload).to include(
        'sub' => target_identity.uuid,
        'aud' => target_issuer,
        'scope' => 'openid token_exchange:passport',
        'act' => { 'sub' => broker_issuer },
      )
    end

    it 'encrypts to the target through the shared encryptor, naming the key in the header' do
      header = JSON.parse(Base64.urlsafe_decode64(subject.token.split('.').first))

      expect(header).to include(
        'alg' => OpenidConnect::JweEncryptor::ALG,
        'enc' => OpenidConnect::JweEncryptor::ENC,
        'kid' => JWT::JWK.new(target_private_key.public_key).kid,
      )
    end

    context 'when the target has no registered certificate' do
      let!(:target) { create(:service_provider, :active, issuer: 'target-issuer', certs: []) }

      it 'raises rather than issuing a token nobody can read' do
        expect { subject }.to raise_error(OpenidConnect::JweEncryptor::NoUsableKeyError)
      end
    end

    it 'returns the configured expiration' do
      expect(subject.expires_in).to eq(600)
    end

    it 'stores delegated access token metadata in Redis by token digest' do
      loaded_access_token = TokenExchange::AccessToken.load(subject.token)

      expect(loaded_access_token).to have_attributes(
        identity_uuid: target_identity.uuid,
        broker_issuer:,
        target_issuer:,
        resource:,
        scope:,
        expires_at: loaded_access_token.issued_at + 600,
      )
    end

    it 'creates a historical issuance linking the actor and target return logs' do
      subject
      issuance = user.delegated_issuance_logs.last

      expect(issuance.actor_return_log).to eq(actor_return_log)
      expect(issuance.target_return_log).to have_attributes(
        issuer: target_issuer,
        billable: true,
      )
    end

    it 'returns the historical issuance delegation id' do
      expect(subject.delegation_id).to eq(user.delegated_issuance_logs.last.delegation_id)
    end

    it 'stores the token with the configured expiration' do
      expect(EncryptedRedisStructStorage).to receive(:store).with(
        instance_of(TokenExchange::AccessToken),
        expires_in: 600,
      )

      subject
    end

    context 'when storing the access token fails' do
      before do
        allow(EncryptedRedisStructStorage).to receive(:store).and_raise(Redis::BaseError)
      end

      it 'leaves no target return log or issuance behind' do
        expect { subject }
          .to raise_error(Redis::BaseError)
          .and change { SpReturnLog.where(issuer: target_issuer).count }.by(0)
          .and change { DelegatedIssuanceLog.count }.by(0)
      end
    end
  end
end
