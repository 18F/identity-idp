require 'rails_helper'

# Encrypted userinfo responses (OpenID Connect Core 1.0 §5.3.2) for a service provider that has
# opted in on its record; the plain JSON response for everyone else is unchanged.
RSpec.describe 'OpenID Connect userinfo encrypted responses' do
  let(:access_token) { SecureRandom.hex }
  let(:userinfo_encrypted_response_alg) { 'RSA-OAEP-256' }
  let(:certs) { ['saml_test_sp'] }
  let(:pkce) { nil }
  let(:service_provider) do
    create(:service_provider, ial: 2, certs:, pkce:, userinfo_encrypted_response_alg:)
  end
  let(:scope) { 'openid email' }
  let(:acr_values) { Saml::Idp::Constants::IAL_AUTH_ONLY_ACR }
  let(:user) { create(:user) }
  let(:identity) do
    create(
      :service_provider_identity,
      rails_session_id: SecureRandom.hex,
      access_token:,
      user:,
      service_provider_record: service_provider,
      scope:,
      acr_values:,
      last_authenticated_at: Time.zone.now,
    )
  end

  before do
    OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
  end

  def userinfo(authorization: "Bearer #{access_token}", headers: {})
    get api_openid_connect_userinfo_path,
        headers: { 'HTTP_AUTHORIZATION' => authorization }.merge(headers)
  end

  # The claims exactly as the plain JSON response carries them for the same identity, read with
  # encryption switched off on the record and then restored.
  def plain_claims
    service_provider.update!(userinfo_encrypted_response_alg: nil)
    userinfo
    expect(response.media_type).to eq('application/json')
    claims = JSON.parse(response.body)
    service_provider.update!(userinfo_encrypted_response_alg:)
    claims
  end

  def jwe_header(compact_jwe)
    JSON.parse(Base64.urlsafe_decode64(compact_jwe.split('.').first))
  end

  describe 'a confidential client that opted in' do
    it 'answers with one compact JWE under application/jwt and nothing in the clear' do
      freeze_time do
        userinfo

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('application/jwt')
        expect(response.body.split('.').length).to eq(5)
        expect(response.body).not_to include(user.email_addresses.first.email)
        expect(response.body).not_to include(identity.uuid)
        expect(response.headers).not_to have_key('WWW-Authenticate')
      end
    end

    it 'encrypts with RSA-OAEP-256 and A256GCM, the header carrying only alg and enc' do
      userinfo

      expect(jwe_header(response.body)).to eq('alg' => 'RSA-OAEP-256', 'enc' => 'A256GCM')
    end

    it 'decrypts with the key of the registered certificate to exactly the plain claims' do
      freeze_time do
        expected = plain_claims
        userinfo

        decrypted = JSON.parse(JWE.decrypt(response.body, saml_test_sp_private_key))
        expect(decrypted).to eq(expected)
        expect(decrypted).to include('sub' => identity.uuid, 'email_verified' => true)
        expect(decrypted['email']).to eq(user.email_addresses.first.email)
      end
    end

    it 'cannot be decrypted with another key' do
      userinfo

      expect { JWE.decrypt(response.body, saml_test_sp2_private_key) }
        .to raise_error(OpenSSL::PKey::RSAError)
    end

    it 'ignores a DPoP header for a bearer token, as the plain response does' do
      userinfo(headers: { 'DPoP' => 'not-even-a-jwt' })

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/jwt')
    end

    it 'logs the authentication with the encrypted flag' do
      stub_request_analytics
      userinfo

      expect(@analytics).to have_logged_event(
        'OpenID Connect: bearer token authentication',
        success: true, ial: identity.ial, client_id: service_provider.issuer, encrypted: true,
      )
    end

    context 'with the document_images scope granted for a verified person' do
      let(:scope) { 'openid email document_images' }
      let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_ACR }
      let(:profile) { create(:profile, :active, :verified) }
      let(:user) { create(:user, profiles: [profile]) }

      before do
        allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
          .and_return([service_provider.issuer])
        identity.update!(biometric_sharing_consent_at: profile.verified_at + 1.second)
        create(
          :document_metadata,
          profile:,
          document_capture_session: create(:document_capture_session, user:),
          document_data: {
            document_number: 'D-5',
            document_issued: '2020-03-03',
            document_expiration: '2030-03-03',
          },
        )
      end

      it 'carries the document metadata claims inside the JWE and nowhere in the clear' do
        freeze_time do
          expected = plain_claims
          expect(expected['document_metadata']).to eq(
            'document_number' => 'D-5',
            'document_issued' => '2020-03-03',
            'document_expiration' => '2030-03-03',
          )

          userinfo

          expect(response.media_type).to eq('application/jwt')
          expect(response.body).not_to include('D-5')
          decrypted = JSON.parse(JWE.decrypt(response.body, saml_test_sp_private_key))
          expect(decrypted).to eq(expected)
          expect(decrypted).to have_key('document_images')
        end
      end
    end
  end

  describe 'a service provider that did not opt in' do
    let(:userinfo_encrypted_response_alg) { nil }

    it 'receives the plain JSON response exactly as before' do
      stub_request_analytics
      userinfo

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      body = JSON.parse(response.body)
      expect(body).to include('sub' => identity.uuid, 'email_verified' => true)
      expect(body['email']).to eq(user.email_addresses.first.email)
      expect(@analytics).to have_logged_event(
        'OpenID Connect: bearer token authentication',
        success: true, ial: identity.ial, client_id: service_provider.issuer, encrypted: false,
      )
    end
  end

  describe 'an opted-in record without a usable key' do
    shared_examples 'a refused request that releases nothing' do
      it 'answers 500 server_error with no claim in the body and logs the failure' do
        stub_request_analytics
        userinfo

        expect(response).to have_http_status(:internal_server_error)
        expect(response.media_type).to eq('application/json')
        expect(JSON.parse(response.body)).to eq(
          'error' => 'server_error',
          'error_description' => t('openid_connect.user_info.errors.encryption_unavailable'),
        )
        expect(response.body).not_to include(user.email_addresses.first.email)
        expect(response.body).not_to include(identity.uuid)
        expect(response.body).not_to include('"sub"')
        expect(@analytics).to have_logged_event(
          :openid_connect_userinfo_encryption_failed,
          client_id: service_provider.issuer,
          error: 'OpenidConnect::UserInfoEncryptor::NoUsableKeyError',
        )
      end
    end

    context 'with no registered certificate' do
      let(:certs) { [] }

      include_examples 'a refused request that releases nothing'
    end

    context 'with a certificate that names a file that does not exist' do
      let(:certs) { ['i_do_not_exist'] }

      include_examples 'a refused request that releases nothing'
    end

    context 'on a public client, even one with a certificate pasted on its record' do
      let(:pkce) { true }

      include_examples 'a refused request that releases nothing'
    end
  end

  describe 'a delegated token' do
    it 'is still refused before any response is built' do
      plaintext = TokenExchangeToken.generate_token
      token = create(:token_exchange_token, plaintext:)
      expect(DelegatedTokenStore.read(plaintext)).to be_present

      userinfo(authorization: "Bearer #{plaintext}")

      expect(response).to have_http_status(:unauthorized)
      expect(response.media_type).to eq('application/json')
      expect(JSON.parse(response.body)['error'])
        .to eq(t('openid_connect.user_info.errors.not_found'))
      DelegatedTokenStore.revoke_grant(token.grant_id)
    end
  end
end
