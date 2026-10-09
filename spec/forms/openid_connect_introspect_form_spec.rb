require 'rails_helper'

RSpec.describe OpenidConnectIntrospectForm do
  include Rails.application.routes.url_helpers

  let(:application) do
    create(:service_provider, :delegation_application, attribute_bundle: %w[email])
  end
  let(:resource_server) do
    create(:token_exchange_resource_server, service_provider: application, certs: ['saml_test_sp'])
  end
  let(:service_provider) do
    create(:service_provider, :delegation_service_provider, pkce: true, certs: [])
  end
  let(:user) { create(:user, :proofed) }
  let!(:identity) do
    IdentityLinker.new(user, service_provider).link_identity(
      ial: 2, rails_session_id: SecureRandom.hex, scope: 'openid email',
      dpop_jkt: dpop_thumbprint
    )
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
      grant:, resource_server:, service_provider:, user:, dpop_jkt: dpop_thumbprint, plaintext:
    )
  end
  let(:client_assertion) do
    build_client_assertion(
      client_id: resource_server.identifier, audience: api_openid_connect_introspect_url,
    )
  end
  let(:params) { { token: plaintext } }

  subject(:form) { described_class.new(params) }

  before do
    allow(IdentityConfig.store).to receive(:token_exchange_enabled).and_return(true)
  end

  describe '#submit' do
    context 'with a resource server assertion' do
      let(:params) do
        {
          token: plaintext,
          client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
          client_assertion:,
        }
      end

      it 'succeeds, answers active, and reports the caller for analytics' do
        result = form.submit

        expect(result.success?).to eq(true)
        expect(result.to_h).to include(
          caller_type: 'resource_server',
          resource_server_identifier: resource_server.identifier,
          service_provider_issuer: nil,
          active: true,
          error_code: nil,
        )
        expect(form.http_status).to eq(:ok)
        expect(form.www_authenticate).to be_nil
        expect(form.response).to include(active: true, aud: resource_server.identifier)
      end

      it 'ignores token_type_hint' do
        form = described_class.new(params.merge(token_type_hint: 'refresh_token'))
        form.submit
        expect(form.response[:active]).to eq(true)
      end

      context 'when the assertion does not verify' do
        let(:client_assertion) do
          build_client_assertion(
            client_id: resource_server.identifier, audience: api_openid_connect_introspect_url,
            key: saml_test_sp2_private_key
          )
        end

        it 'fails with invalid_client and 401, naming the claimed caller' do
          result = form.submit

          expect(result.success?).to eq(false)
          expect(result.to_h).to include(
            caller_type: 'resource_server',
            resource_server_identifier: resource_server.identifier,
            active: nil,
            error_code: 'invalid_client',
          )
          expect(result.to_h[:integration_errors]).to include(
            event: :oidc_introspection_request,
            integration_exists: true,
            request_issuer: resource_server.identifier,
          )
          expect(form.http_status).to eq(:unauthorized)
          expect(form.www_authenticate).to be_nil
          expect(form.response[:error]).to eq('invalid_client')
          expect(form.response[:error_description]).to be_present
          expect(form.response.keys).not_to include(:active)
        end
      end
    end

    context 'with a public client and a proof' do
      let(:params) { { token: plaintext, client_id: service_provider.issuer, dpop_proof: } }
      let(:dpop_proof) do
        build_dpop_proof(url: api_openid_connect_introspect_url, access_token: plaintext)
      end

      it 'succeeds with the limited response' do
        result = form.submit

        expect(result.success?).to eq(true)
        expect(result.to_h).to include(
          caller_type: 'service_provider',
          service_provider_issuer: service_provider.issuer,
          resource_server_identifier: nil,
          active: true,
        )
        expect(form.response.keys).to contain_exactly(
          :active, :iss, :aud, :scope, :client_id, :delegation_id, :token_type, :iat, :exp, :cnf,
          :sub
        )
      end

      context 'when the proof is missing' do
        let(:dpop_proof) { nil }

        it 'fails with invalid_dpop_proof and a DPoP challenge' do
          result = form.submit

          expect(result.success?).to eq(false)
          expect(result.to_h).to include(
            caller_type: 'service_provider', error_code: 'invalid_dpop_proof', active: nil,
          )
          expect(form.http_status).to eq(:unauthorized)
          description = t('openid_connect.token.errors.dpop_proof_required').gsub(/["\\]/, '')
          expect(form.www_authenticate).to eq(
            %(DPoP algs="ES256 RS256", error="invalid_dpop_proof", ) +
              %(error_description="#{description}"),
          )
          expect(form.response[:error]).to eq('invalid_dpop_proof')
        end
      end

      context 'when the proof key is not the one the token is bound to' do
        let(:dpop_proof) do
          build_dpop_proof(
            url: api_openid_connect_introspect_url, access_token: plaintext,
            key: OpenSSL::PKey::EC.generate('prime256v1')
          )
        end

        it 'succeeds with active false' do
          result = form.submit
          expect(result.success?).to eq(true)
          expect(result.to_h).to include(caller_type: 'service_provider', active: false)
          expect(form.response).to eq(active: false)
        end
      end
    end

    context 'with a token containing a null byte' do
      let(:params) do
        {
          token: "abc\x00def",
          client_assertion_type: OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE,
          client_assertion:,
        }
      end

      it 'answers active false without consulting the store' do
        expect(DelegatedTokenStore).not_to receive(:read)
        form.submit
        expect(form.response).to eq(active: false)
      end
    end

    context 'with no credential' do
      it 'succeeds with active false and no caller' do
        result = form.submit

        expect(result.success?).to eq(true)
        expect(result.to_h).to include(caller_type: 'none', active: false, error_code: nil)
        expect(result.to_h[:integration_errors]).to be_nil
        expect(form.http_status).to eq(:ok)
        expect(form.response).to eq(active: false)
      end
    end

    context 'with a confidential client naming itself' do
      let(:service_provider) do
        create(
          :service_provider, :delegation_service_provider, pkce: false,
                                                           certs: ['saml_test_sp']
        )
      end
      let!(:identity) do
        IdentityLinker.new(user, service_provider).link_identity(
          ial: 2, rails_session_id: SecureRandom.hex, scope: 'openid email',
        )
      end
      let(:params) { { token: plaintext, client_id: service_provider.issuer } }

      it 'treats the name as no credential' do
        result = form.submit
        expect(result.to_h).to include(caller_type: 'none', active: false)
        expect(form.response).to eq(active: false)
      end
    end
  end
end
