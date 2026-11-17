require 'rails_helper'

RSpec.describe OpenidConnect::UserInfoController do
  let(:json_response) { JSON.parse(response.body).with_indifferent_access }

  describe '#show' do
    subject(:action) do
      request.headers['HTTP_AUTHORIZATION'] = authorization_header
      post :show
    end

    context 'without an authorization header' do
      let(:authorization_header) { nil }

      it '401s' do
        action
        expect(response).to be_unauthorized
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          dpop_bound: false,
          success: false,
          error_details: hash_including(:access_token),
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Access token No Authorization header provided. Please see our documentation at ' \
            'https://developers.login.gov/support/#no-auth-header',
          ),
          error_types: { access_token: true },
          event: :oidc_bearer_token_auth,
          integration_exists: false,
        )
      end
    end

    context 'with a malformed authorization header' do
      let(:authorization_header) { 'Boooorer ABCDEF' }

      it '401s' do
        action
        expect(response).to be_unauthorized
        expect(json_response[:error])
          .to eq(t('openid_connect.user_info.errors.malformed_authorization'))
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          dpop_bound: false,
          success: false,
          error_details: hash_including(:access_token),
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Access token Malformed Authorization header. Please see our documentation at ' \
            'https://developers.login.gov/support/#malformed-auth-header',
          ),
          error_types: { access_token: true },
          event: :oidc_bearer_token_auth,
          integration_exists: false,
        )
      end
    end

    context 'with an invalid bearer token' do
      let(:authorization_header) { 'Bearer ABCDEF' }

      it '401s' do
        action
        expect(response).to be_unauthorized
        expect(json_response[:error]).to be_present
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          dpop_bound: false,
          success: false,
          error_details: hash_including(:access_token),
        )

        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          error_details: array_including(
            'Access token Could not find authorization for the contents of the provided ' \
              'access_token or it may have expired. Please see our documentation at ' \
              'https://developers.login.gov/support/#auth-header-contents-not-found',
          ),
          error_types: { access_token: true },
          event: :oidc_bearer_token_auth,
          integration_exists: false,
        )
      end
    end

    context 'with a bearer token for an expired session' do
      let(:access_token) { SecureRandom.urlsafe_base64 }
      let(:rails_session_id) { 'missing-session-id' } # Emulate expired by missing, which has no TTL
      let!(:identity) { create(:service_provider_identity, access_token:, rails_session_id:) }
      let(:authorization_header) { "Bearer #{access_token}" }

      it '401s' do
        action
        expect(response).to be_unauthorized
        expect(json_response[:error]).to eq(t('openid_connect.user_info.errors.not_found'))
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          dpop_bound: false,
          success: false,
          error_details: { access_token: { not_found: true } },
        )
      end
    end

    context 'with a token of a client listed for key binding' do
      let(:service_provider) do
        create(:service_provider, :active, issuer: 'bound-client', pkce: true)
      end
      let(:access_token) { SecureRandom.hex }
      let(:identity) do
        create(
          :service_provider_identity,
          service_provider: service_provider.issuer,
          rails_session_id: SecureRandom.hex,
          access_token:,
          user: create(:user),
        )
      end
      let(:url) { 'http://www.example.com/api/openid_connect/userinfo' }
      let(:authorization_header) { "DPoP #{access_token}" }

      before do
        allow(IdentityConfig.store).to receive(:dpop_required_issuers)
          .and_return([service_provider.issuer])
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
        AccessTokenBinding.store(access_token:, dpop_jkt: dpop_thumbprint, expires_in: 50)
      end

      context 'under the DPoP scheme with a proof from the bound key' do
        before do
          request.headers['DPoP'] =
            build_dpop_proof(http_url: url, http_method: 'POST', access_token:)
        end

        it 'renders user info' do
          action
          expect(response).to be_ok
          expect(json_response[:sub]).to eq(identity.uuid)
        end
      end

      context 'presented as a Bearer token' do
        let(:authorization_header) { "Bearer #{access_token}" }

        it '401s with a DPoP challenge' do
          action
          expect(response.status).to eq(401)
          expect(response.headers['WWW-Authenticate']).to eq(
            'DPoP algs="ES256 RS256", error="invalid_token"',
          )
          expect(json_response[:error]).to eq(
            'dpop_bearer_presented',
          )
        end
      end

      context 'under the DPoP scheme without a proof' do
        it '401s as an invalid proof' do
          action
          expect(response.status).to eq(401)
          expect(response.headers['WWW-Authenticate']).to eq(
            'DPoP algs="ES256 RS256", error="invalid_dpop_proof"',
          )
          expect(json_response[:error]).to eq('dpop_proof_missing')
        end
      end
    end

    context 'with a valid bearer token' do
      let(:authorization_header) { "Bearer #{access_token}" }
      let(:access_token) { SecureRandom.hex }
      let(:identity) do
        create(
          :service_provider_identity, rails_session_id: SecureRandom.hex,
                                      access_token: access_token, user: create(:user)
        )
      end
      before do
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
      end

      it 'renders user info' do
        action
        expect(response).to be_ok
        expect(json_response[:sub]).to eq(identity.uuid)
      end

      it 'tracks analytics' do
        stub_analytics

        action

        expect(@analytics).to have_logged_event(
          'OpenID Connect: bearer token authentication',
          dpop_bound: false,
          success: true,
          client_id: identity.service_provider,
          ial: identity.ial,
          encrypted: false,
        )

        expect(@analytics).to_not have_logged_event(
          :sp_integration_errors_present,
        )
      end

      it 'only changes the paths visited in session' do
        action
        session_hash = {
          'events' => { 'OpenID Connect: bearer token authentication' => true },
          'first_event' => true,
        }
        expect(request.session.to_h).to eq(session_hash)
      end

      context 'when document image sharing is authorized but artifacts have not landed' do
        let(:user) { create(:user) }
        let(:identity) do
          create(
            :service_provider_identity,
            rails_session_id: SecureRandom.hex,
            access_token:,
            user:,
            scope: 'openid document_images',
            acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
            biometric_sharing_consent_at: Time.zone.now,
          )
        end

        before do
          create(:profile, :active, user:, verified_at: 1.hour.ago)
          allow(IdentityConfig.store).to receive(:document_images_sharing_enabled)
            .and_return(true)
          allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
            .and_return([identity.service_provider])
        end

        it 'serializes an empty document_images object through to the JSON response' do
          action

          expect(response).to be_ok
          expect(json_response).to have_key(:document_images)
          expect(json_response[:document_images]).to eq({})
        end
      end

      context 'with an authentication event' do
        let(:authentication_event_at) { Time.zone.parse('2026-07-01 12:00:00 UTC') }
        let(:remember_device_at) { Time.zone.parse('2026-07-01 12:30:00 UTC') }
        let(:federation_at) { Time.zone.parse('2026-07-01 13:00:00 UTC') }

        before do
          identity.update!(last_authenticated_at: federation_at)
          write_out_of_band_user_session(
            session_uuid: identity.rails_session_id,
            user_session: {
              auth_events: [
                {
                  auth_method: TwoFactorAuthenticatable::AuthMethod::SMS,
                  at: authentication_event_at,
                },
                {
                  auth_method: TwoFactorAuthenticatable::AuthMethod::REMEMBER_DEVICE,
                  at: remember_device_at,
                },
              ],
            },
          )
        end

        it 'returns the latest IdP authentication event instead of the identity timestamp' do
          action

          expect(json_response[:auth_time]).to eq(authentication_event_at.to_i)
        end
      end

      context 'with session expiring after validation and before render' do
        before do
          allow_any_instance_of(AccessTokenVerifier).to receive(:submit).and_wrap_original do |impl|
            result = impl.call
            OutOfBandSessionAccessor.new(identity.rails_session_id).destroy
            result
          end
        end

        it 'renders user info' do
          action
          expect(response).to be_ok
          expect(json_response[:sub]).to eq(identity.uuid)
        end
      end
    end

    context 'with the site_key scope on a key-bound token' do
      let(:url) { 'http://www.example.com/api/openid_connect/userinfo' }
      let(:authorization_header) { "DPoP #{access_token}" }
      let(:access_token) { SecureRandom.hex }
      let(:service_provider) do
        create(:service_provider, :active, issuer: 'site-key-client', pkce: true)
      end
      let(:user) { create(:user) }
      let(:site_key) { create_site_key(user) }
      let(:identity) do
        create(
          :service_provider_identity,
          service_provider: service_provider.issuer,
          scope: 'openid site_key',
          rails_session_id: SecureRandom.hex,
          access_token:,
          user:,
        )
      end

      before do
        allow_site_keys_for(service_provider)
        accessor = OutOfBandSessionAccessor.new(identity.rails_session_id)
        accessor.put_empty_user_session(50)
        accessor.put_site_key(site_key.private_key, 50)
        AccessTokenBinding.store(access_token:, dpop_jkt: dpop_thumbprint, expires_in: 50)
        request.headers['DPoP'] =
          build_dpop_proof(http_url: url, http_method: 'POST', access_token:)
      end

      it 'returns the private key sealed to the proof key, openable only by that key' do
        action

        expect(response).to be_ok
        sealed = json_response[:site_key]
        opened = JSON.parse(
          open_site_key_jwe(
            sealed, recipient_key: dpop_key,
                    client_id: service_provider.issuer
          ),
        )
        expect(opened).to eq(JSON.parse(SiteKeys::KeyPair.from_private_bytes(site_key.private_key).private_jwk.to_json))
      end

      it 'returns the public key beside it' do
        action

        expect(json_response[:site_key_public]).to eq(JSON.parse(user.reload.site_key.public_key))
      end

      it 'cannot be opened with another key' do
        action

        sealed = json_response[:site_key]
        expect do
          open_site_key_jwe(
            sealed, recipient_key: OpenSSL::PKey::EC.generate('prime256v1'),
                    client_id: service_provider.issuer
          )
        end.to raise_error(OpenSSL::Cipher::CipherError)
      end

      context 'when the private key is not in the session' do
        before do
          accessor = OutOfBandSessionAccessor.new(identity.rails_session_id)
          accessor.destroy
          accessor.put_empty_user_session(50)
        end

        it 'omits the site key claims but still answers' do
          action

          expect(response).to be_ok
          expect(json_response).not_to have_key(:site_key)
          expect(json_response).not_to have_key(:site_key_public)
          expect(json_response[:sub]).to eq(identity.uuid)
        end
      end
    end
  end

  # Opens the site_key claim JWE as a recipient page would, from the standards, to pin the format.
  def open_site_key_jwe(sealed, recipient_key:, client_id:)
    header_b64, _cek, iv_b64, ct_b64, tag_b64 = sealed.split('.')
    header = JSON.parse(Base64.urlsafe_decode64(header_b64))
    epk = JWT::JWK.import(header['epk'].transform_keys(&:to_sym)).verify_key
    shared = recipient_key.dh_compute_key(epk.public_key)
    other = [header['enc'].bytesize].pack('N') + header['enc'] + [0].pack('N') +
            [client_id.bytesize].pack('N') + client_id + [256].pack('N')
    cek = OpenSSL::Digest::SHA256.digest([1].pack('N') + shared + other)[0, 32]
    cipher = OpenSSL::Cipher.new('aes-256-gcm').decrypt
    cipher.key = cek
    cipher.iv = Base64.urlsafe_decode64(iv_b64)
    cipher.auth_tag = Base64.urlsafe_decode64(tag_b64)
    cipher.auth_data = header_b64
    cipher.update(Base64.urlsafe_decode64(ct_b64)) + cipher.final
  end
end
