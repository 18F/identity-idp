require 'rails_helper'

RSpec.describe OpenidConnectIntrospectionForm do
  include Rails.application.routes.url_helpers

  subject(:form) { described_class.new(params) }

  let(:params) do
    {
      client_assertion:,
      client_assertion_type:,
      client_id:,
      token:,
      token_type_hint: 'access_token',
    }
  end
  let(:broker_issuer) { 'broker-issuer' }
  let!(:target) do
    create(
      :service_provider,
      :active,
      issuer: token_target_issuer,
      certs: ['saml_test_sp2', 'saml_test_sp'],
    )
  end
  let(:client_id) { target_issuer }
  let(:token_target_issuer) { 'target-issuer' }
  let(:target_issuer) { token_target_issuer }
  let(:subject_token) do
    TokenExchange::SubjectToken.new(
      id: 'subject-token-digest',
      user_id: 1,
      identity_uuid: 'identity-uuid',
      broker_issuer:,
      scope: 'openid token_exchange:passport',
      ial: 2,
      issued_at: Time.zone.now.to_i,
    )
  end
  let(:access_token) do
    TokenExchange::AccessTokenIssuer.issue(
      subject_token:,
      target_issuer: target.issuer,
      resource: 'https://api.example.gov/passport',
      scope: 'openid token_exchange:passport',
    ).token
  end
  let(:token) { access_token }
  let(:client_assertion_type) { TokenExchange::Constants::CLIENT_ASSERTION_TYPE }
  let(:client_assertion) { JWT.encode(jwt_payload, client_private_key, 'RS256') }
  let(:aud) { api_openid_connect_introspect_url }
  let(:jwt_payload) do
    {
      iss: target_issuer,
      sub: target_issuer,
      aud:,
      jti: SecureRandom.hex,
      exp: 5.minutes.from_now.to_i,
      iat: Time.zone.now.to_i,
    }
  end
  let(:client_private_key) do
    OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read)
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:token_exchange_allowed_target_issuers)
      .and_return([token_target_issuer])
  end

  describe '#submit' do
    it 'is successful with valid private_key_jwt authentication' do
      expect(form.submit.success?).to eq(true)
    end

    context 'when token exchange is disabled' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(false)
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:client_id]).to include('is invalid')
      end

      it 'does not validate the client assertion' do
        expect(OpenidConnectClientAssertionValidator).to_not receive(:new)

        form.submit
      end

      it 'does not load the token from Redis' do
        expect(TokenExchange::AccessToken).to_not receive(:load)

        form.submit
        form.response
      end

      it 'does not disclose whether the token is active' do
        form.submit

        expect(form.response[:error]).to eq('invalid_client')
        expect(form.response).to_not have_key(:active)
      end
    end

    context 'when the target is not on the allowlist' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_target_issuers)
          .and_return([])
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:client_id]).to include('is invalid')
      end

      it 'does not disclose whether the token is active' do
        form.submit

        expect(form.response[:error]).to eq('invalid_client')
        expect(form.response).to_not have_key(:active)
      end
    end

    context 'when another target is on the allowlist' do
      before do
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_target_issuers)
          .and_return(['some-other-target'])
      end

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:client_id]).to include('is invalid')
      end
    end

    %i[client_assertion client_assertion_type client_id token].each do |attribute|
      context "with missing #{attribute}" do
        let(attribute) { nil }

        it 'is invalid' do
          expect(form.submit.success?).to eq(false)
          expect(form.errors[attribute]).to include('Please fill in this field.')
        end
      end
    end

    context 'with invalid client_assertion_type' do
      let(:client_assertion_type) { 'urn:ietf:params:oauth:grant-type:jwt-bearer' }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:client_assertion_type]).to include('is not included in the list')
      end
    end

    context 'with inactive target service provider' do
      before { target.update!(active: false) }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:client_id]).to include('is invalid')
      end
    end

    context 'with invalid assertion audience' do
      let(:aud) { api_openid_connect_token_url }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:client_assertion]).to include(
          t('openid_connect.token.errors.invalid_aud', url: api_openid_connect_introspect_url),
        )
      end
    end

    context 'with an expired assertion' do
      before { jwt_payload[:exp] = 5.minutes.ago.to_i }

      it 'is invalid' do
        expect(form.submit.success?).to eq(false)
        expect(form.errors[:client_assertion]).to include('Signature has expired')
      end
    end
  end

  describe '#response' do
    subject(:response) { form.response }

    it 'returns RFC 7662 active token metadata' do
      loaded_access_token = TokenExchange::AccessToken.load(access_token)

      expect(response).to include(
        active: true,
        client_id: broker_issuer,
        sub: target_issuer,
        iss: root_url,
        exp: loaded_access_token.expires_at,
        iat: loaded_access_token.issued_at,
        aud: target_issuer,
        act: { sub: broker_issuer },
        scope: 'openid token_exchange:passport',
      )
    end

    it 'identifies the broker as the client that requested the token' do
      expect(response[:client_id]).to eq(broker_issuer)
      expect(response[:client_id]).to_not eq(target_issuer)
    end

    context 'with an unknown access token' do
      let(:access_token) { 'unknown-token' }

      it 'returns inactive' do
        expect(response).to eq(active: false)
      end
    end

    context 'when the token belongs to another target' do
      let(:target_issuer) { 'another-target' }

      before do
        create(
          :service_provider,
          :active,
          issuer: target_issuer,
          certs: ['saml_test_sp2', 'saml_test_sp'],
        )
        allow(IdentityConfig.store).to receive(:token_exchange_allowed_target_issuers)
          .and_return([token_target_issuer, target_issuer])
      end

      it 'returns inactive' do
        expect(response).to eq(active: false)
      end
    end

    context 'when the token has expired but is still present in Redis' do
      before do
        expired_access_token = TokenExchange::AccessToken.load(access_token)
        expired_access_token.expires_at = 1.second.ago.to_i
        EncryptedRedisStructStorage.store(expired_access_token, expires_in: 600)
      end

      it 'returns inactive' do
        expect(response).to eq(active: false)
      end
    end

    context 'when the stored expiration is missing' do
      before do
        access_token_without_expiration = TokenExchange::AccessToken.load(access_token)
        access_token_without_expiration.expires_at = nil
        EncryptedRedisStructStorage.store(access_token_without_expiration, expires_in: 600)
      end

      it 'fails closed and returns inactive' do
        expect(response).to eq(active: false)
      end
    end

    context 'when client authentication is invalid' do
      let(:aud) { api_openid_connect_token_url }

      it 'returns invalid_client' do
        expect(response[:error]).to eq('invalid_client')
        expect(response[:error_description]).to be_present
      end
    end
  end
end
