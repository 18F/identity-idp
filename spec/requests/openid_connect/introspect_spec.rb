require 'rails_helper'

# RFC 7662 introspection at POST /api/openid_connect/introspect. Housing Assistance Records
# (Department of Housing Support) verifies a token MyBenefits Assistant (Office of Benefits
# Coordination) obtained for its API; MyBenefits Assistant, a browser-based public client, checks
# its own token.
RSpec.describe 'OpenID Connect token introspection' do
  include Rails.application.routes.url_helpers

  let(:token_exchange_enabled) { true }
  let(:user) { create(:user, :proofed) }
  let(:agency) { create(:agency, name: 'Department of Housing Support') }
  let(:attribute_bundle) { %w[email first_name last_name] }
  let(:shareable_attributes) { [] }
  let(:application) do
    create(
      :service_provider, :delegation_application,
      agency:,
      issuer: 'urn:gov:gsa:openidconnect:sp:records_agency',
      friendly_name: 'Housing Assistance Records',
      delegation_scope_value: 'housing_records',
      ial: 2,
      attribute_bundle:,
      delegation_sp_shareable_attributes: shareable_attributes
    )
  end
  let(:resource_server) do
    create(
      :token_exchange_resource_server,
      service_provider: application,
      identifier: 'https://records-api.housing.example.gov',
      certs: ['saml_test_sp'],
    )
  end
  let(:service_provider) do
    create(
      :service_provider, :delegation_service_provider,
      issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits',
      friendly_name: 'MyBenefits Assistant',
      pkce: true, certs: [],
      redirect_uris: ['https://mybenefits.example.gov/auth/result']
    )
  end
  let(:rails_session_id) { SecureRandom.hex }
  let(:sign_in_at) { Time.zone.parse('2026-10-09 14:00:00 UTC') }
  let!(:identity) do
    IdentityLinker.new(user, service_provider).link_identity(
      acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
      ial: 2,
      rails_session_id:,
      scope: 'openid email token_exchange:housing_records',
      dpop_jkt: dpop_thumbprint,
    ).tap { |linked| linked.update!(last_authenticated_at: sign_in_at) }
  end
  let!(:grant) do
    TokenExchangeGrant.approve!(
      user:, service_provider:, application:, source: 'consent_screen', remember: true,
    )
  end
  let(:plaintext) { TokenExchangeToken.generate_token }
  let!(:token) do
    create(
      :token_exchange_token, :key_bound,
      grant:, resource_server:, service_provider:, user:,
      dpop_jkt: dpop_thumbprint,
      sp_rails_session_id: rails_session_id,
      plaintext:
    )
  end
  let(:pii) do
    {
      first_name: 'Ada',
      last_name: 'Lovelace',
      dob: '12/10/1815',
      address1: '12 Analytical Way',
      city: 'Washington',
      state: 'DC',
      zipcode: '20001',
      phone: '(202) 555-0100',
      ssn: '900-11-2222',
    }
  end

  def json
    JSON.parse(response.body, symbolize_names: true)
  end

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled)
      .and_return(token_exchange_enabled)
    OutOfBandSessionAccessor.new(rails_session_id).put_pii(
      profile_id: user.active_profile.id, pii:, expiration: 300,
    )
  end

  # Each call signs a fresh assertion: the jti of the last one has been used.
  def introspect_as_agency(presented = plaintext, caller: resource_server.identifier, **claims)
    post api_openid_connect_introspect_path, params: {
      token: presented,
      client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
      client_assertion: build_client_assertion(
        client_id: caller, audience: api_openid_connect_introspect_url, **claims,
      ),
    }
  end

  def introspect_as_service_provider(presented = plaintext, key: dpop_key, proof: :fresh,
                                     client_id: service_provider.issuer)
    if proof == :fresh
      proof = build_dpop_proof(
        url: api_openid_connect_introspect_url, access_token: presented, key:,
      )
    end
    post api_openid_connect_introspect_path,
         params: { token: presented, client_id: },
         headers: { 'DPoP' => proof }.compact
  end

  describe 'the agency API asking about a token issued for it' do
    it 'answers with the token, the actor, the sign-in and the person as the agency knows them' do
      introspect_as_agency

      expect(response).to have_http_status(:ok)
      expect(json.keys).to contain_exactly(
        :active, :iss, :aud, :scope, :client_id, :delegation_id, :token_type, :iat, :exp, :cnf,
        :sub, :act, :jti, :acr, :aal, :auth_time, :session_live,
        :email, :email_verified, :given_name, :family_name
      )
      expect(json).to include(
        active: true,
        iss: root_url,
        aud: resource_server.identifier,
        scope: 'token_exchange:housing_records',
        client_id: service_provider.issuer,
        act: { sub: service_provider.issuer },
        delegation_id: grant.delegation_id,
        token_type: 'DPoP',
        cnf: { jkt: dpop_thumbprint },
        iat: token.issued_at.to_i,
        exp: token.expires_at.to_i,
        jti: DelegatedTokenStore.digest(plaintext),
        acr: Saml::Idp::Constants::IAL_VERIFIED_ACR,
        aal: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
        auth_time: sign_in_at.to_i,
        session_live: true,
        email: identity.email_address_for_sharing.email,
        email_verified: true,
        given_name: 'Ada',
        family_name: 'Lovelace',
      )
    end

    it 'identifies the person by the agency identifier a direct sign-in would use' do
      expect { introspect_as_agency }
        .to change { AgencyIdentity.where(user:, agency:).count }.from(0).to(1)

      agency_identity = AgencyIdentity.find_by(user:, agency:)
      expect(json[:sub]).to eq(agency_identity.uuid)
      expect(json[:sub]).not_to eq(identity.uuid)
      expect(json[:sub]).not_to eq(user.uuid)
    end

    it 'reuses the identifier when the person has used the agency before' do
      existing = AgencyIdentity.create!(user:, agency:, uuid: SecureRandom.uuid)
      introspect_as_agency
      expect(json[:sub]).to eq(existing.uuid)
    end

    it 'creates no connection to the application' do
      expect { introspect_as_agency }.not_to(change { ServiceProviderIdentity.count })
      expect(ServiceProviderIdentity.where(service_provider: application.issuer)).to be_empty
    end

    it 'logs the call' do
      stub_request_analytics
      introspect_as_agency

      expect(@analytics).to have_logged_event(
        :openid_connect_introspect,
        success: true,
        caller_type: 'resource_server',
        resource_server_identifier: resource_server.identifier,
        active: true,
      )
      expect(@analytics).not_to have_logged_event(:sp_integration_errors_present)
    end

    context 'when the agency is registered for proofed attributes' do
      let(:attribute_bundle) do
        %w[email all_emails first_name dob ssn phone address1 address2 city state zipcode
           verified_at]
      end

      it 'carries them in userinfo shape, filtered by the bundle alone' do
        introspect_as_agency

        expect(json).to include(
          email: identity.email_address_for_sharing.email,
          all_emails: user.confirmed_email_addresses.map(&:email),
          given_name: 'Ada',
          birthdate: '1815-12-10',
          social_security_number: '900-11-2222',
          phone: '+12025550100',
          phone_verified: true,
          verified_at: user.active_profile.verified_at.to_i,
          address: {
            formatted: "12 Analytical Way\nWashington, DC 20001",
            street_address: '12 Analytical Way',
            locality: 'Washington',
            region: 'DC',
            postal_code: '20001',
          },
        )
        # The bundle names first_name but not last_name; the service provider's own scopes
        # (openid email) play no part.
        expect(json.keys).not_to include(:family_name, :locale, :ial)
      end
    end

    context 'when the bundle names nothing beyond email' do
      let(:attribute_bundle) { %w[email] }

      it 'releases email only' do
        introspect_as_agency
        expect(json.keys).not_to include(:given_name, :family_name, :all_emails, :address)
        expect(json[:email]).to be_present
      end
    end

    context 'after the sign-in to the service provider has ended' do
      let(:attribute_bundle) { %w[email all_emails first_name last_name ssn] }

      before { OutOfBandSessionAccessor.new(rails_session_id).destroy }

      it 'still confirms the token but carries only the identifiers and email, and says so' do
        introspect_as_agency

        expect(response).to have_http_status(:ok)
        expect(json).to include(
          active: true,
          session_live: false,
          delegation_id: grant.delegation_id,
          act: { sub: service_provider.issuer },
          email: identity.email_address_for_sharing.email,
          email_verified: true,
          all_emails: user.confirmed_email_addresses.map(&:email),
        )
        expect(json[:sub]).to eq(AgencyIdentity.find_by(user:, agency:).uuid)
        expect(json.keys).not_to include(
          :given_name, :family_name, :social_security_number, :verified_at
        )
      end
    end

    context 'when the token was issued at IALmax for a verified person' do
      let!(:token) do
        create(
          :token_exchange_token, :key_bound,
          grant:, resource_server:, service_provider:, user:,
          dpop_jkt: dpop_thumbprint, sp_rails_session_id: rails_session_id,
          ial: Idp::Constants::IAL_MAX, plaintext:
        )
      end

      it 'reports the verified assurance and releases proofed attributes' do
        introspect_as_agency
        expect(json[:acr]).to eq(Saml::Idp::Constants::IAL_VERIFIED_ACR)
        expect(json[:given_name]).to eq('Ada')
      end
    end

    context 'when the sign-in recorded no authentication assurance' do
      let!(:token) do
        create(
          :token_exchange_token, :key_bound,
          grant:, resource_server:, service_provider:, user:,
          dpop_jkt: dpop_thumbprint, sp_rails_session_id: rails_session_id,
          aal: nil, plaintext:
        )
      end

      it 'reports what the service provider sign-in asserted' do
        identity.update!(
          requested_aal_value: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
        )
        introspect_as_agency
        expect(json[:aal])
          .to eq(Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF)
      end
    end

    context 'for a bearer token issued to a confidential service provider' do
      let(:service_provider) do
        create(
          :service_provider, :delegation_service_provider,
          issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits', pkce: false, certs: ['saml_test_sp']
        )
      end
      let!(:identity) do
        IdentityLinker.new(user, service_provider).link_identity(
          acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR, ial: 2, rails_session_id:,
          scope: 'openid email'
        )
      end
      let!(:token) do
        create(
          :token_exchange_token,
          grant:, resource_server:, service_provider:, user:,
          sp_rails_session_id: rails_session_id, plaintext:
        )
      end

      it 'reports Bearer and no key binding' do
        introspect_as_agency
        expect(json[:token_type]).to eq('Bearer')
        expect(json.keys).not_to include(:cnf)
      end
    end
  end

  describe 'the agency API asking about a token that is not, or is no longer, a live delegation' do
    shared_examples 'not active' do
      it 'answers exactly {"active": false} with no reason' do
        introspect_as_agency
        expect(response).to have_http_status(:ok)
        expect(json).to eq(active: false)
      end
    end

    context 'when the token was issued for another API' do
      let(:other_resource_server) do
        create(:token_exchange_resource_server, certs: ['saml_test_sp'])
      end

      it 'answers exactly {"active": false} to the other API' do
        introspect_as_agency(caller: other_resource_server.identifier)
        expect(response).to have_http_status(:ok)
        expect(json).to eq(active: false)
      end
    end

    context 'when the token is unknown' do
      let(:plaintext) { TokenExchangeToken.generate_token }
      let!(:token) { nil }

      include_examples 'not active'
    end

    context 'when the token is missing from the request' do
      let(:plaintext) { nil }

      include_examples 'not active'
    end

    context 'when the token has expired' do
      it 'answers exactly {"active": false}' do
        travel_to(token.expires_at + 1.second) { introspect_as_agency }
        expect(json).to eq(active: false)
      end
    end

    context 'when the approval was revoked' do
      before { grant.revoke!(reason: 'user_revoked') }

      include_examples 'not active'
    end

    context 'when the remembered approval has lapsed' do
      before { grant.update!(remember_until: 1.minute.ago) }

      include_examples 'not active'
    end

    context 'when the person is suspended' do
      before { user.update!(suspended_at: Time.zone.now) }

      include_examples 'not active'
    end

    context 'when the API URL is inactive' do
      before { resource_server.update!(active: false) }

      include_examples 'not active'
    end

    context 'when the application is inactive' do
      before { application.update!(active: false) }

      include_examples 'not active'
    end

    context 'when the service provider is no longer approved for delegation' do
      before { service_provider.update!(token_exchange_enabled_sp: false) }

      include_examples 'not active'
    end

    context 'when the service provider is inactive' do
      before { service_provider.update!(active: false) }

      include_examples 'not active'
    end

    it 'logs an inactive answer' do
      stub_request_analytics
      grant.revoke!(reason: 'user_revoked')
      introspect_as_agency
      expect(@analytics).to have_logged_event(
        :openid_connect_introspect,
        hash_including(success: true, caller_type: 'resource_server', active: false),
      )
    end
  end

  describe 'the agency API presenting a credential that fails' do
    shared_examples 'invalid_client' do
      it 'answers 401 invalid_client without a word about the token' do
        expect(response).to have_http_status(:unauthorized)
        expect(json[:error]).to eq('invalid_client')
        expect(json[:error_description]).to be_present
        expect(json.keys).not_to include(:active)
        expect(response.headers['WWW-Authenticate']).to be_nil
      end
    end

    context 'with an assertion signed by a key the API did not register' do
      before { introspect_as_agency(key: saml_test_sp2_private_key) }

      include_examples 'invalid_client'

      it 'logs the integration error' do
        stub_request_analytics
        introspect_as_agency(key: saml_test_sp2_private_key)
        expect(@analytics).to have_logged_event(
          :openid_connect_introspect,
          hash_including(
            success: false, caller_type: 'resource_server', error_code: 'invalid_client',
            resource_server_identifier: resource_server.identifier
          ),
        )
        expect(@analytics).to have_logged_event(
          :sp_integration_errors_present,
          hash_including(
            event: :oidc_introspection_request,
            integration_exists: true,
            request_issuer: resource_server.identifier,
          ),
        )
      end
    end

    context 'with an assertion from an unregistered caller' do
      before { introspect_as_agency(caller: 'https://nowhere.example.gov') }

      include_examples 'invalid_client'
    end

    context 'with an assertion minted for the token endpoint' do
      before { introspect_as_agency(aud: api_openid_connect_token_url) }

      include_examples 'invalid_client'
    end

    context 'with an assertion whose lifetime exceeds five minutes' do
      before do
        now = Time.zone.now.to_i
        introspect_as_agency(iat: now, exp: now + 600)
      end

      include_examples 'invalid_client'
    end

    context 'with the wrong client_assertion_type' do
      before do
        post api_openid_connect_introspect_path, params: {
          token: plaintext,
          client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:saml2-bearer',
          client_assertion: build_client_assertion(
            client_id: resource_server.identifier, audience: api_openid_connect_introspect_url,
          ),
        }
      end

      include_examples 'invalid_client'
    end

    it 'refuses a replayed assertion' do
      assertion = build_client_assertion(
        client_id: resource_server.identifier, audience: api_openid_connect_introspect_url,
      )
      2.times do
        post api_openid_connect_introspect_path, params: {
          token: plaintext,
          client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
          client_assertion: assertion,
        }
      end
      expect(response).to have_http_status(:unauthorized)
      expect(json[:error]).to eq('invalid_client')
    end
  end

  describe 'the service provider asking about its own token' do
    it 'answers the token status and what its own sign-in already told it, nothing more' do
      introspect_as_service_provider

      expect(response).to have_http_status(:ok)
      expect(json.keys).to contain_exactly(
        :active, :iss, :aud, :scope, :client_id, :delegation_id, :token_type, :iat, :exp, :cnf,
        :sub
      )
      expect(json).to include(
        active: true,
        iss: root_url,
        aud: resource_server.identifier,
        scope: 'token_exchange:housing_records',
        client_id: service_provider.issuer,
        delegation_id: grant.delegation_id,
        token_type: 'DPoP',
        cnf: { jkt: dpop_thumbprint },
        iat: token.issued_at.to_i,
        exp: token.expires_at.to_i,
        sub: AgencyIdentityLinker.new(identity).link_identity.uuid,
      )
      expect(json[:sub]).not_to eq(AgencyIdentity.find_by(user:, agency:)&.uuid)
    end

    it 'never creates the agency identifier' do
      expect { introspect_as_service_provider }.not_to(change { AgencyIdentity.count })
    end

    it 'logs the call' do
      stub_request_analytics
      introspect_as_service_provider
      expect(@analytics).to have_logged_event(
        :openid_connect_introspect,
        success: true,
        caller_type: 'service_provider',
        service_provider_issuer: service_provider.issuer,
        active: true,
      )
    end

    context 'when the application shares attributes with service providers' do
      let(:attribute_bundle) { %w[email first_name last_name] }
      let(:shareable_attributes) { %w[first_name ssn] }

      it 'adds those the application itself receives, and no other' do
        introspect_as_service_provider
        expect(json).to include(given_name: 'Ada')
        expect(json.keys).not_to include(:family_name, :social_security_number, :email, :act)
      end

      it 'omits them once the sign-in has ended' do
        OutOfBandSessionAccessor.new(rails_session_id).destroy
        introspect_as_service_provider
        expect(json[:active]).to eq(true)
        expect(json.keys).not_to include(:given_name, :session_live)
      end
    end

    context 'when the proof is signed by a key other than the one the token is bound to' do
      it 'answers exactly {"active": false}, as to any party that is not the holder' do
        introspect_as_service_provider(key: OpenSSL::PKey::EC.generate('prime256v1'))
        expect(response).to have_http_status(:ok)
        expect(json).to eq(active: false)
      end
    end

    context 'when the token was issued to a different service provider' do
      let(:other_service_provider) do
        create(:service_provider, :delegation_service_provider, pkce: true, certs: [])
      end

      it 'answers exactly {"active": false}' do
        introspect_as_service_provider(client_id: other_service_provider.issuer)
        expect(json).to eq(active: false)
      end
    end

    context 'when the token is unknown' do
      it 'answers exactly {"active": false}' do
        introspect_as_service_provider(TokenExchangeToken.generate_token)
        expect(json).to eq(active: false)
      end
    end

    context 'when the approval was revoked' do
      before { grant.revoke!(reason: 'user_revoked') }

      it 'answers exactly {"active": false}' do
        introspect_as_service_provider
        expect(json).to eq(active: false)
      end
    end

    context 'when the service provider is a confidential client' do
      let(:service_provider) do
        create(
          :service_provider, :delegation_service_provider,
          issuer: 'urn:gov:gsa:openidconnect:sp:mybenefits', pkce: false, certs: ['saml_test_sp']
        )
      end

      it 'is not a credential: exactly {"active": false}' do
        introspect_as_service_provider
        expect(response).to have_http_status(:ok)
        expect(json).to eq(active: false)
      end
    end

    context 'when the client_id is unknown' do
      it 'answers exactly {"active": false}' do
        introspect_as_service_provider(client_id: 'urn:nobody')
        expect(json).to eq(active: false)
      end
    end

    describe 'a proof that fails' do
      shared_examples 'invalid_dpop_proof' do
        it 'answers 401 with a DPoP challenge and no word about the token' do
          expect(response).to have_http_status(:unauthorized)
          expect(response.headers['WWW-Authenticate'])
            .to start_with('DPoP algs="ES256 RS256", error="invalid_dpop_proof"')
          expect(json[:error]).to eq('invalid_dpop_proof')
          expect(json.keys).not_to include(:active)
        end
      end

      context 'missing' do
        before { introspect_as_service_provider(proof: nil) }

        include_examples 'invalid_dpop_proof'

        it 'says a proof is required' do
          expect(json[:error_description])
            .to eq(t('openid_connect.token.errors.dpop_proof_required'))
        end

        it 'logs the failure' do
          stub_request_analytics
          introspect_as_service_provider(proof: nil)
          expect(@analytics).to have_logged_event(
            :openid_connect_introspect,
            hash_including(
              success: false, caller_type: 'service_provider',
              service_provider_issuer: service_provider.issuer, error_code: 'invalid_dpop_proof'
            ),
          )
        end
      end

      context 'without ath over the token' do
        before do
          introspect_as_service_provider(
            proof: build_dpop_proof(url: api_openid_connect_introspect_url),
          )
        end

        include_examples 'invalid_dpop_proof'
      end

      context 'for another endpoint' do
        before do
          introspect_as_service_provider(
            proof: build_dpop_proof(url: api_openid_connect_token_url, access_token: plaintext),
          )
        end

        include_examples 'invalid_dpop_proof'
      end

      context 'replayed' do
        before do
          proof = build_dpop_proof(url: api_openid_connect_introspect_url, access_token: plaintext)
          2.times { introspect_as_service_provider(proof:) }
        end

        include_examples 'invalid_dpop_proof'
      end
    end
  end

  describe 'a request with no credential' do
    it 'answers exactly {"active": false}' do
      post api_openid_connect_introspect_path, params: { token: plaintext }
      expect(response).to have_http_status(:ok)
      expect(json).to eq(active: false)
    end

    it 'logs the call with no caller' do
      stub_request_analytics
      post api_openid_connect_introspect_path, params: { token: plaintext }
      expect(@analytics).to have_logged_event(
        :openid_connect_introspect,
        success: true, caller_type: 'none', active: false,
      )
    end
  end

  describe 'cross-origin calls from the service provider' do
    before { Rails.cache.clear }
    after { Rails.cache.clear }

    it 'answers the preflight for a registered origin' do
      service_provider
      process(
        :options, api_openid_connect_introspect_path, params: {},
                                                      headers: {
                                                        'HTTP_ORIGIN' => 'https://mybenefits.example.gov',
                                                      }
      )

      expect(response).to have_http_status(:ok)
      expect(response.body).to be_empty
      expect(response['Access-Control-Allow-Origin']).to eq('https://mybenefits.example.gov')
      expect(response['Access-Control-Allow-Methods']).to eq('POST, OPTIONS')
      expect(response['Access-Control-Allow-Credentials']).to eq('true')
    end

    it 'carries the CORS headers on the POST itself' do
      service_provider
      post api_openid_connect_introspect_path,
           params: { token: plaintext, client_id: service_provider.issuer },
           headers: {
             'HTTP_ORIGIN' => 'https://mybenefits.example.gov',
             'DPoP' => build_dpop_proof(
               url: api_openid_connect_introspect_url, access_token: plaintext,
             ),
           }

      expect(response['Access-Control-Allow-Origin']).to eq('https://mybenefits.example.gov')
      expect(json[:active]).to eq(true)
    end

    it 'does not answer an unregistered origin' do
      service_provider
      process(
        :options, api_openid_connect_introspect_path, params: {},
                                                      headers: { 'HTTP_ORIGIN' => 'https://foo.example.com' }
      )
      expect(response['Access-Control-Allow-Origin']).to be_nil
    end
  end

  context 'when delegated access is switched off' do
    let(:token_exchange_enabled) { false }

    it 'is not found' do
      introspect_as_agency
      expect(response).to have_http_status(:not_found)
    end
  end
end
