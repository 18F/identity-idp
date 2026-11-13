require 'rails_helper'

RSpec.describe TokenExchange::AccessTokenIssuer do
  describe '.issue' do
    subject(:subject) do
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
        identity_uuid: actor_identity.uuid,
        actor_issuer:,
        scope:,
        ial: 2,
        actor_return_log_id: actor_return_log.id,
        issued_at: Time.zone.now.to_i,
      )
    end
    let(:user) { create(:user) }
    let!(:target) { create(:service_provider, :active, issuer: 'target-issuer') }
    let!(:actor) { create(:service_provider, :active, issuer: 'actor-issuer') }
    let(:target_issuer) { target.issuer }
    let(:actor_issuer) { actor.issuer }
    let(:target_private_key) do
      OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read)
    end
    let(:actor_identity) do
      create(:service_provider_identity, service_provider: actor_issuer, user:)
    end
    let(:actor_return_log) do
      create(:sp_return_log, user:, issuer: actor_issuer, ial: 2, billable: true)
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
        'act' => { 'sub' => actor_issuer },
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

    it 'carries no cnf claim' do
      jwt = JWE.decrypt(subject.token, target_private_key)
      payload = JWT.decode(
        jwt, Rails.application.config.oidc_public_key, true,
        algorithm: IdTokenBuilder::JWT_SIGNING_ALGORITHM
      ).first

      expect(payload).not_to have_key('cnf')
    end

    context 'when the token is bound to the actor\'s key' do
      let(:dpop_jkt) { SecureRandom.urlsafe_base64(32) }
      subject(:subject) do
        described_class.issue(subject_token:, target_issuer:, resource:, scope:, dpop_jkt:)
      end

      it 'carries the key thumbprint as cnf.jkt and stores it on the record' do
        jwt = JWE.decrypt(subject.token, target_private_key)
        payload = JWT.decode(
          jwt, Rails.application.config.oidc_public_key, true,
          algorithm: IdTokenBuilder::JWT_SIGNING_ALGORITHM
        ).first

        expect(payload['cnf']).to eq('jkt' => dpop_jkt)
        expect(TokenExchange::AccessToken.load(subject.token).dpop_jkt).to eq(dpop_jkt)
      end
    end

    it 'returns the configured expiration' do
      expect(subject.expires_in).to eq(600)
    end

    it 'stores delegated access token metadata in Redis by token digest' do
      loaded_access_token = TokenExchange::AccessToken.load(subject.token)

      expect(loaded_access_token).to have_attributes(
        identity_uuid: target_identity.uuid,
        actor_issuer:,
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

    it 'leaves the agency identity untouched and opens no session with the agency' do
      target_identity.update!(last_authenticated_at: 2.days.ago)
      connection_columns = %w[deleted_at last_authenticated_at session_uuid rails_session_id]

      expect { subject }
        .not_to(change { target_identity.reload.attributes.slice(*connection_columns) })
      expect(target_identity).to have_attributes(session_uuid: nil, rails_session_id: nil)
    end

    context 'when the person disconnected the agency application from their account' do
      before { RevokeServiceProviderConsent.new(target_identity).call }

      it 'issues nothing and writes no agency return log or issuance' do
        expect { subject }
          .to raise_error
          .and change { SpReturnLog.where(issuer: target_issuer).count }.by(0)
          .and change { DelegatedIssuanceLog.count }.by(0)
      end
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
