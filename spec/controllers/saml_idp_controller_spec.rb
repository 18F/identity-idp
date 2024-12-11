require 'rails_helper'

RSpec.describe SamlIdpController do
  include SamlAuthHelper

  render_views

  let(:path_year) { SamlAuthHelper::PATH_YEAR }

  describe '/api/saml/logout' do
    it 'assigns devise session limited failure redirect url' do
      delete :logout, params: { path_year: path_year }

      expect(request.env['devise_session_limited_failure_redirect_url']).to eq(request.url)
    end

    it 'tracks the event when idp initiated' do
      stub_analytics

      delete :logout, params: { path_year: path_year }

      expect(@analytics).to have_logged_event(
        'Logout Initiated',
        hash_including(sp_initiated: false, oidc: false, saml_request_valid: true),
      )
    end

    it 'tracks the event when sp initiated' do
      allow(controller).to receive(:saml_request).and_return(FakeSamlLogoutRequest.new)
      stub_analytics

      delete :logout, params: { SAMLRequest: 'foo', path_year: path_year }

      expect(@analytics).to have_logged_event(
        'Logout Initiated',
        hash_including(sp_initiated: true, oidc: false, saml_request_valid: true),
      )
    end

    it 'tracks the event when the saml request is invalid' do
      stub_analytics

      delete :logout, params: { SAMLRequest: 'foo', path_year: path_year }

      expect(@analytics).to have_logged_event(
        'Logout Initiated',
        hash_including(sp_initiated: true, oidc: false, saml_request_valid: false),
      )
      expect(@analytics).to have_logged_event(
        :integration_errors_present,
        error_details: [:issuer_missing_or_invald, :no_auth_or_logout_request, :invalid_signature],
        error_types: { saml_request_errors: true },
        event: :saml_logout_request,
        integration_exists: false,
      )
    end

    let(:service_provider) do
      create(
        :service_provider,
        certs: ['sp_sinatra_demo', 'saml_test_sp'],
        active: true,
        assertion_consumer_logout_service_url: 'https://example.com',
      )
    end

    let(:right_cert_settings) do
      saml_settings(
        overrides: {
          issuer: service_provider.issuer,
          assertion_consumer_logout_service_url: 'https://example.com',
        },
      )
    end

    let(:wrong_cert_settings) do
      saml_settings(
        overrides: {
          issuer: service_provider.issuer,
          certificate: File.read(Rails.root.join('certs', 'sp', 'saml_test_sp2.crt')),
          private_key: OpenSSL::PKey::RSA.new(
            File.read(Rails.root + 'keys/saml_test_sp2.key'),
          ).to_pem,
        },
      )
    end

    it 'accepts requests from a correct cert' do
      saml_request = UriService.params(
        OneLogin::RubySaml::Logoutrequest.new.create(right_cert_settings),
      )[:SAMLRequest]

      payload = [
        ['SAMLRequest', saml_request],
        ['RelayState', 'aaa'],
        ['SigAlg', 'SHA256'],
      ]
      canon_string = payload.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join('&')

      private_sp_key = OpenSSL::PKey::RSA.new(right_cert_settings.private_key)
      signature = private_sp_key.sign(OpenSSL::Digest.new('SHA256'), canon_string)

      certificate = OpenSSL::X509::Certificate.new(right_cert_settings.certificate)

      # This is the same verification process we expect the SAML gem will run
      expect(
        certificate.public_key.verify(
          OpenSSL::Digest.new('SHA256'),
          signature,
          canon_string,
        ),
      ).to eq(true)

      delete :logout, params: payload.to_h.merge(
        Signature: Base64.encode64(signature),
        path_year: path_year,
      )

      expect(response).to be_ok
    end

    context 'when the cert is not registered' do
      it 'rejects requests from a wrong cert' do
        delete :logout, params: UriService.params(
          OneLogin::RubySaml::Logoutrequest.new.create(wrong_cert_settings),
        ).merge(path_year: path_year)

        expect(response).to be_bad_request
      end

      it 'tracks the request' do
        stub_analytics

        delete :logout, params: UriService.params(
          OneLogin::RubySaml::Logoutrequest.new.create(wrong_cert_settings),
        ).merge(path_year: path_year)

        expect(@analytics).to have_logged_event(
          'Logout Initiated',
          hash_including(sp_initiated: true, oidc: false, saml_request_valid: false),
        )
        expect(@analytics).to have_logged_event(
          :integration_errors_present,
          error_details: [:invalid_signature],
          error_types: { saml_request_errors: true },
          event: :saml_logout_request,
          integration_exists: true,
          request_issuer: service_provider.issuer,
        )
      end
    end

    context 'cert element in SAML request is blank' do
      let(:user) { create(:user, :fully_registered) }
      let(:service_provider) { build(:service_provider, issuer: 'http://localhost:3000') }

      # the RubySAML library won't let us pass an empty string in as the certificate
      # element, so this test substitutes a SAMLRequest that has that element blank
      let(:blank_cert_element_req) do
        <<-XML.gsub(/^[\s]+|[\s]+\n/, '')
          <?xml version="1.0"?>
          <samlp:LogoutRequest xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" Destination="http://www.example.com/api/saml/logout2024" ID="_223d186c-35a0-4d1f-b81a-c473ad496415" IssueInstant="2024-01-11T18:22:03Z" Version="2.0">
            <saml:Issuer>http://localhost:3000</saml:Issuer>
            <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
              <ds:SignedInfo>
                <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
                <ds:Reference URI="#_223d186c-35a0-4d1f-b81a-c473ad496415">
                  <ds:Transforms>
                    <ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
                    <ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#">
                      <ec:InclusiveNamespaces xmlns:ec="http://www.w3.org/2001/10/xml-exc-c14n#" PrefixList="#default samlp saml ds xs xsi md"/>
                    </ds:Transform>
                  </ds:Transforms>
                  <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                  <ds:DigestValue>2Nb3RLbiFHn0cyn+7JA7hWbbK1NvFMVGa4MYTb3Q91I=</ds:DigestValue>
                </ds:Reference>
              </ds:SignedInfo>
              <ds:SignatureValue>UmsRcaWkHXrUnBMfOQBC2DIQk1rkQqMc5oucz6FAjulq0ZX7qT+zUbSZ7K/us+lzcL1hrgHXi2wxjKSRiisWrJNSmbIGGZIa4+U8wIMhkuY5vZVKgxRc2aP88i/lWwURMI183ifAzCwpq5Y4yaJ6pH+jbgYOtmOhcXh1OwrI+QqR7QSglyUJ55WO+BCR07Hf8A7DSA/Wgp9xH+DUw1EnwbDdzoi7TFqaHY8S4SWIcc26DHsq88mjsmsxAFRQ+4t6nadOnrrFnJWKJeiFlD8MxcQuBiuYBetKRLIPxyXKFxjEn7EkJ5zDkkrBWyUT4VT/JnthUlD825D+v81ZXIX3Tg==</ds:SignatureValue>
              <ds:KeyInfo>
                <ds:X509Data>
                  <ds:X509Certificate>
                  </ds:X509Certificate>
                </ds:X509Data>
              </ds:KeyInfo>
            </ds:Signature>
            <saml:NameID Format="urn:oasis:names:tc:SAML:2.0:nameid-format:transient">_13ae90d1-2f9b-4ed5-b84d-3722ea42e386</saml:NameID>
          </samlp:LogoutRequest>
        XML
      end
      let(:deflated_encoded_req) do
        Base64.encode64(Zlib::Deflate.deflate(blank_cert_element_req, 9)[2..-5])
      end

      it 'a ValidationError is raised' do
        expect do
          delete :logout, params: {
            'SAMLRequest' => deflated_encoded_req,
            path_year:,
          }
        end.to raise_error(
          SamlIdp::XMLSecurity::SignedDocument::ValidationError,
          'Certificate element present in response (ds:X509Certificate) but evaluating to nil',
        )
      end
    end
  end

  describe '/api/saml/remotelogout' do
    it 'tracks the event when the saml request is invalid' do
      stub_analytics

      post :remotelogout, params: { SAMLRequest: 'foo', path_year: path_year }

      expect(@analytics).to have_logged_event('Remote Logout initiated', saml_request_valid: false)
      expect(@analytics).to have_logged_event(
        :integration_errors_present,
        error_details: [:issuer_missing_or_invald, :no_auth_or_logout_request, :invalid_signature],
        error_types: { saml_request_errors: true },
        event: :saml_remote_logout_request,
        integration_exists: false,
      )
    end

    let(:agency) { create(:agency) }
    let(:service_provider) do
      create(
        :service_provider,
        certs: ['sp_sinatra_demo', 'saml_test_sp'],
        active: true,
        assertion_consumer_logout_service_url: 'https://example.com',
        agency_id: agency.id,
      )
    end
    let(:other_sp) { create(:service_provider, active: true, agency_id: agency.id) }

    let(:session_id) { 'abc123' }
    let(:user) { create(:user, :fully_registered) }
    let(:other_user) { create(:user, :fully_registered) }

    let!(:identity) do
      ServiceProviderIdentity.create(
        service_provider: service_provider.issuer,
        user: user,
        rails_session_id: session_id,
      )
    end
    let!(:other_identity) do
      ServiceProviderIdentity.create(
        service_provider: other_sp.issuer,
        user: other_user,
      )
    end

    let!(:agency_identity) do
      AgencyIdentity.create!(
        agency: agency,
        user: user,
        uuid: identity.uuid,
      )
    end
    let!(:other_agency_identity) do
      AgencyIdentity.create!(
        agency: agency,
        user: other_user,
        uuid: other_identity.uuid,
      )
    end

    let(:right_cert_settings) do
      saml_settings(
        overrides: {
          issuer: service_provider.issuer,
          assertion_consumer_logout_service_url: 'https://example.com',
          sessionindex: agency_identity.uuid,
        },
      )
    end

    let(:right_cert_no_session_settings) do
      saml_settings(
        overrides: {
          issuer: service_provider.issuer,
          assertion_consumer_logout_service_url: 'https://example.com',
        },
      )
    end

    let(:right_cert_bad_session_settings) do
      saml_settings(
        overrides: {
          issuer: service_provider.issuer,
          assertion_consumer_logout_service_url: 'https://example.com',
          sessionindex: 'abc123',
        },
      )
    end

    let(:right_cert_bad_user_settings) do
      saml_settings(
        overrides: {
          issuer: service_provider.issuer,
          assertion_consumer_logout_service_url: 'https://example.com',
          sessionindex: other_agency_identity.uuid,
        },
      )
    end

    let(:wrong_cert_settings) do
      saml_settings(
        overrides: {
          issuer: service_provider.issuer,
          certificate: File.read(Rails.root.join('certs', 'sp', 'saml_test_sp2.crt')),
          private_key: OpenSSL::PKey::RSA.new(
            File.read(Rails.root + 'keys/saml_test_sp2.key'),
          ).to_pem,
        },
      )
    end

    it 'accepts requests with correct cert and correct session index and renders logout response' do
      REDIS_POOL.with { |client| client.flushdb }
      session_accessor = OutOfBandSessionAccessor.new(session_id)
      session_accessor.put_pii(profile_id: 123, pii: { foo: 'bar' })
      saml_request = OneLogin::RubySaml::Logoutrequest.new
      encoded_saml_request = UriService.params(
        saml_request.create(right_cert_settings),
      )[:SAMLRequest]

      payload = [
        ['SAMLRequest', encoded_saml_request],
        ['RelayState', 'aaa'],
        ['SigAlg', 'SHA256'],
      ]
      canon_string = payload.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join('&')

      private_sp_key = OpenSSL::PKey::RSA.new(right_cert_settings.private_key)
      signature = private_sp_key.sign(OpenSSL::Digest.new('SHA256'), canon_string)

      certificate = OpenSSL::X509::Certificate.new(right_cert_settings.certificate)

      # This is the same verification process we expect the SAML gem will run
      expect(
        certificate.public_key.verify(
          OpenSSL::Digest.new('SHA256'),
          signature,
          canon_string,
        ),
      ).to eq(true)

      post :remotelogout, params: payload.to_h.merge(
        Signature: Base64.encode64(signature),
        path_year: path_year,
      )

      expect(response).to be_ok
      expect(OutOfBandSessionAccessor.new(session_id).load_pii(123)).to be_nil

      logout_response = OneLogin::RubySaml::Logoutresponse.new(response.body)
      expect(logout_response.success?).to eq(true)
      expect(logout_response.in_response_to).to eq(saml_request.uuid)
      REDIS_POOL.with { |client| client.flushdb }
    end

    it 'rejects requests from a correct cert but no session index' do
      saml_request = UriService.params(
        OneLogin::RubySaml::Logoutrequest.new.create(right_cert_no_session_settings),
      )[:SAMLRequest]

      payload = [
        ['SAMLRequest', saml_request],
        ['RelayState', 'aaa'],
        ['SigAlg', 'SHA256'],
      ]
      canon_string = payload.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join('&')

      private_sp_key = OpenSSL::PKey::RSA.new(right_cert_settings.private_key)
      signature = private_sp_key.sign(OpenSSL::Digest.new('SHA256'), canon_string)

      certificate = OpenSSL::X509::Certificate.new(right_cert_settings.certificate)

      # This is the same verification process we expect the SAML gem will run
      expect(
        certificate.public_key.verify(
          OpenSSL::Digest.new('SHA256'),
          signature,
          canon_string,
        ),
      ).to eq(true)

      stub_analytics
      post :remotelogout, params: payload.to_h.merge(
        Signature: Base64.encode64(signature),
        path_year: path_year,
      )

      expect(response).to be_bad_request
      expect(@analytics).to have_logged_event(
        :integration_errors_present,
        error_details: [:no_user_found_from_session_index],
        error_types: { saml_request_errors: true },
        event: :saml_remote_logout_request,
        integration_exists: true,
        request_issuer: service_provider.issuer,
      )
    end

    it 'rejects requests from a correct cert but bad session index' do
      saml_request = UriService.params(
        OneLogin::RubySaml::Logoutrequest.new.create(right_cert_bad_session_settings),
      )[:SAMLRequest]

      payload = [
        ['SAMLRequest', saml_request],
        ['RelayState', 'aaa'],
        ['SigAlg', 'SHA256'],
      ]
      canon_string = payload.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join('&')

      private_sp_key = OpenSSL::PKey::RSA.new(right_cert_settings.private_key)
      signature = private_sp_key.sign(OpenSSL::Digest.new('SHA256'), canon_string)

      certificate = OpenSSL::X509::Certificate.new(right_cert_settings.certificate)

      # This is the same verification process we expect the SAML gem will run
      expect(
        certificate.public_key.verify(
          OpenSSL::Digest.new('SHA256'),
          signature,
          canon_string,
        ),
      ).to eq(true)

      stub_analytics
      post :remotelogout, params: payload.to_h.merge(
        Signature: Base64.encode64(signature),
        path_year: path_year,
      )

      expect(response).to be_bad_request
      expect(@analytics).to have_logged_event(
        :integration_errors_present,
        error_details: [:no_user_found_from_session_index],
        error_types: { saml_request_errors: true },
        event: :saml_remote_logout_request,
        integration_exists: true,
        request_issuer: service_provider.issuer,
      )
    end

    it 'rejects requests from a correct cert but a non-associated user' do
      saml_request = UriService.params(
        OneLogin::RubySaml::Logoutrequest.new.create(right_cert_bad_user_settings),
      )[:SAMLRequest]

      payload = [
        ['SAMLRequest', saml_request],
        ['RelayState', 'aaa'],
        ['SigAlg', 'SHA256'],
      ]
      canon_string = payload.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join('&')

      private_sp_key = OpenSSL::PKey::RSA.new(right_cert_settings.private_key)
      signature = private_sp_key.sign(OpenSSL::Digest.new('SHA256'), canon_string)

      certificate = OpenSSL::X509::Certificate.new(right_cert_settings.certificate)

      # This is the same verification process we expect the SAML gem will run
      expect(
        certificate.public_key.verify(
          OpenSSL::Digest.new('SHA256'),
          signature,
          canon_string,
        ),
      ).to eq(true)

      stub_analytics
      post :remotelogout, params: payload.to_h.merge(
        Signature: Base64.encode64(signature),
        path_year: path_year,
      )

      expect(response).to be_bad_request
      expect(@analytics).to have_logged_event(
        :integration_errors_present,
        error_details: [:no_user_found_from_session_index],
        error_types: { saml_request_errors: true },
        event: :saml_remote_logout_request,
        integration_exists: true,
        request_issuer: service_provider.issuer,
      )
    end

    it 'rejects requests from a wrong cert' do
      stub_analytics
      post :remotelogout, params: UriService.params(
        OneLogin::RubySaml::Logoutrequest.new.create(wrong_cert_settings),
      ).merge(path_year: path_year)

      expect(response).to be_bad_request
      expect(@analytics).to have_logged_event(
        :integration_errors_present,
        error_details: [:invalid_signature],
        error_types: { saml_request_errors: true },
        event: :saml_remote_logout_request,
        integration_exists: true,
        request_issuer: service_provider.issuer,
      )
    end
  end

  describe '/api/saml/metadata' do
    before do
      get :metadata, params: { path_year: path_year }
    end

    let(:org_name) { 'login.gov' }
    let(:xmldoc) { SamlResponseDoc.new('controller', 'metadata', response) }

    it 'renders XML inline' do
      expect(response.media_type).to eq 'text/xml'
    end

    it 'contains an EntityDescriptor nodeset' do
      expect(xmldoc.metadata_nodeset.length).to eq(1)
    end

    it 'contains the correct NameID formats' do
      # matching the spec, section 8.3
      expect(name_id_version(xmldoc.metadata_name_id_format('emailAddress'))).to eq('1.1')
      expect(name_id_version(xmldoc.metadata_name_id_format('persistent'))).to eq('2.0')
    end

    it 'contains a signature nodeset' do
      expect(xmldoc.signature_nodeset.length).to eq(1)
    end

    it 'contains a signature method nodeset with SHA256 algorithm' do
      expect(xmldoc.signature_method_nodeset.length).to eq(1)

      expect(xmldoc.signature_method_nodeset[0].attr('Algorithm')).
        to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
    end

    it 'contains a digest method nodeset with SHA256 algorithm' do
      expect(xmldoc.digest_method_nodeset.length).to eq(1)

      expect(xmldoc.digest_method_nodeset[0].attr('Algorithm')).
        to eq('http://www.w3.org/2001/04/xmlenc#sha256')
    end

    it 'contains the organization name under AttributeAuthorityDescriptor' do
      expect(xmldoc.attribute_authority_organization_name).
        to eq org_name
    end

    it 'contains the org display name under AttributeAuthorityDescriptor' do
      expect(xmldoc.attribute_authority_organization_display_name).
        to eq org_name
    end

    it 'contains the organization name' do
      expect(xmldoc.organization_name).
        to eq org_name
    end

    it 'contains the organization display name' do
      expect(xmldoc.organization_display_name).
        to eq org_name
    end

    it 'disables caching' do
      expect(response.headers['Pragma']).to eq 'no-cache'
    end

    def name_id_version(format_urn)
      m = /^urn:oasis:names:tc:SAML:(?<version>\d\.\d):nameid-format:\w+$/.match(format_urn)
      m[:version]
    end
  end

  describe 'GET /api/saml/auth' do
    before do
      # All the tests here were written prior to the interstitial
      # authorization confirmation page so let's force the system
      # to skip past that page
      allow(controller).to receive(:auth_count).and_return(2)
    end

    let(:xmldoc) { SamlResponseDoc.new('controller', 'response_assertion', response) }
    let(:aal_level) { 1 }
    let(:ial2_settings) do
      saml_settings(
        overrides: {
          issuer: sp1_issuer,
          authn_context: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        },
      )
    end
    let(:ialmax_settings) do
      saml_settings(
        overrides: {
          issuer: sp1_issuer,
          authn_context: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          authn_context_comparison: 'minimum',
        },
      )
    end

    context 'when a request is made with a VTR in the authn context' do
      let(:user) { create(:user, :fully_registered) }

      before do
        allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
        stub_sign_in(user)
      end

      context 'the request does not require identity proofing' do
        it 'redirects the user' do
          vtr_settings = saml_settings(
            overrides: {
              issuer: sp1_issuer,
              authn_context: 'C1',
            },
          )
          saml_get_auth(vtr_settings)
          expect(response).to redirect_to(sign_up_completed_url)
          expect(controller.session[:sp][:vtr]).to eq(['C1'])
        end
      end

      context 'the request requires identity proofing' do
        it 'redirects to identity proofing' do
          vtr_settings = saml_settings(
            overrides: {
              issuer: sp1_issuer,
              authn_context: 'C1.C2.P1',
            },
          )
          saml_get_auth(vtr_settings)
          expect(response).to redirect_to(idv_url)
          expect(controller.session[:sp][:vtr]).to eq(['C1.C2.P1'])
        end
      end

      context 'the request requires identity proofing with a facial match' do
        let(:vtr_settings) do
          saml_settings(
            overrides: {
              issuer: sp1_issuer,
              authn_context: 'C1.C2.P1.Pb',
            },
          )
        end
        let(:pii) do
          Pii::Attributes.new_from_hash(
            first_name: 'Some',
            last_name: 'One',
            ssn: '666666666',
          )
        end

        before do
          create(:profile, :active, user: user, pii: pii.to_h)
          Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(
            pii,
            user.reload.active_profile.id,
          )
        end

        context 'the user has proofed without a facial match check' do
          before do
            user.active_profile.update!(idv_level: :legacy_unsupervised)
          end

          it 'redirects to identity proofing for a user who is verified without a facial match' do
            saml_get_auth(vtr_settings)
            expect(response).to redirect_to(idv_url)
            expect(controller.session[:sp][:vtr]).to eq(['C1.C2.P1.Pb'])
          end

          context 'user has a pending facial match profile' do
            let(:vtr_settings) do
              saml_settings(
                overrides: {
                  issuer: sp1_issuer,
                  authn_context: 'C1.C2.P1',
                },
              )
            end

            it 'does not redirect to proofing if sp does not request facial match' do
              create(
                :profile,
                :verify_by_mail_pending,
                :with_pii,
                idv_level: :unsupervised_with_selfie,
                user: user,
              )
              saml_get_auth(vtr_settings)
              expect(response).to redirect_to(sign_up_completed_url)
              expect(controller.session[:sp][:vtr]).to eq(['C1.C2.P1'])
            end

            it 'redirects to the please call page if user has a fraudualent profile' do
              create(
                :profile,
                :fraud_review_pending,
                :with_pii,
                idv_level: :unsupervised_with_selfie,
                user: user,
              )

              saml_get_auth(vtr_settings)
              expect(response).to redirect_to(idv_please_call_url)
              expect(controller.session[:sp][:vtr]).to eq(['C1.C2.P1'])
            end
          end
        end

        context 'the user has proofed with a facial match check remotely' do
          before do
            user.active_profile.update!(idv_level: :unsupervised_with_selfie)
          end

          it 'does not redirect to proofing' do
            saml_get_auth(vtr_settings)
            expect(response).to redirect_to(sign_up_completed_url)
            expect(controller.session[:sp][:vtr]).to eq(['C1.C2.P1.Pb'])
          end
        end

        context 'the user has proofed with a facial match check in-person' do
          before do
            user.active_profile.update!(idv_level: :in_person)
          end

          it 'does not redirect to proofing' do
            saml_get_auth(vtr_settings)
            expect(response).to redirect_to(sign_up_completed_url)
            expect(controller.session[:sp][:vtr]).to eq(['C1.C2.P1.Pb'])
          end
        end
      end

      context 'the VTR is not parsable' do
        it 'renders an error' do
          vtr_settings = saml_settings(
            overrides: {
              issuer: sp1_issuer,
              authn_context: 'Fa.Ke.Va.Lu.E0',
            },
          )
          saml_get_auth(vtr_settings)
          expect(controller).to render_template('saml_idp/auth/error')
          expect(response.status).to eq(400)
          expect(response.body).to include(t('errors.messages.unauthorized_authn_context'))
        end
      end
    end

    context 'with IAL2 and the identity is already verified' do
      let(:user) { create(:profile, :active, :verified).user }
      let(:pii) do
        Pii::Attributes.new_from_hash(
          first_name: 'Some',
          last_name: 'One',
          ssn: '666666666',
          zipcode: '12345',
        )
      end
      let(:this_authn_request) do
        ial2_authnrequest = saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer,
            authn_context: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
          },
        )
        raw_req = CGI.unescape ial2_authnrequest.split('SAMLRequest').last
        SamlIdp::Request.from_deflated_request(raw_req)
      end
      let(:asserter) do
        AttributeAsserter.new(
          user: user,
          service_provider: ServiceProvider.find_by(issuer: sp1_issuer),
          authn_request: this_authn_request,
          name_id_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          decrypted_pii: pii,
          user_session: {},
        )
      end
      let(:sign_in_flow) { :sign_in }

      before do
        stub_sign_in(user)
        session[:sign_in_flow] = sign_in_flow
        IdentityLinker.new(user, sp1).link_identity(ial: Idp::Constants::IAL2)
        user.identities.last.update!(
          verified_attributes: %w[given_name family_name social_security_number address],
        )
        allow(subject).to receive(:attribute_asserter) { asserter }

        if pii.present?
          Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(
            pii,
            user.active_profile.id,
          )
        end
      end

      it 'calls AttributeAsserter#build' do
        expect(asserter).to receive(:build).at_least(:once).and_call_original

        saml_get_auth(ial2_settings)
      end

      it 'sets identity ial' do
        saml_get_auth(ial2_settings)
        expect(user.identities.last.ial).to eq(Idp::Constants::IAL2)
      end

      it 'does not redirect the user to the IdV URL' do
        saml_get_auth(ial2_settings)

        expect(response).to_not be_redirect
      end

      it 'contains verified attributes' do
        saml_get_auth(ial2_settings)

        expect(xmldoc.attribute_node_for('address1')).to be_nil

        %w[first_name last_name ssn zipcode].each do |attr|
          node_value = xmldoc.attribute_value_for(attr)
          expect(node_value).to eq(pii[attr])
        end

        expect(xmldoc.attribute_value_for('verified_at')).to eq(
          user.active_profile.verified_at.iso8601,
        )
      end

      it 'tracks IAL2 authentication events' do
        stub_analytics

        allow(controller).to receive(:identity_needs_verification?).and_return(false)
        saml_get_auth(ial2_settings)

        expect(@analytics).to have_logged_event(
          'SAML Auth Request', {
            authn_context: [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF],
            requested_ial: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            service_provider: sp1_issuer,
            force_authn: false,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
            user_fully_authenticated: true,
          }
        )
        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: true,
            errors: {},
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF],
            authn_context_comparison: 'exact',
            requested_ial: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            service_provider: sp1_issuer,
            endpoint: "/api/saml/auth#{path_year}",
            idv: false,
            finish_profile: false,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
          ),
        )
        expect(@analytics).to have_logged_event(
          'SP redirect initiated',
          ial: Idp::Constants::IAL2,
          billed_ial: Idp::Constants::IAL2,
          sign_in_flow:,
          acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
        )
      end

      context 'profile is not in session' do
        let(:pii) { nil }

        it 'redirects to password capture if profile is verified but not in session' do
          saml_get_auth(ial2_settings)
          expect(response).to redirect_to capture_password_url
        end
      end
    end

    context 'with IAL2 and the profile is reset' do
      it 'redirects to reactivate account path' do
        user = create(:profile, :verified, :password_reset).user
        generate_saml_response(user, ial2_settings)

        expect(response).to redirect_to reactivate_account_path
      end
    end

    context 'with IAL1' do
      it 'does not redirect the user to the IdV URL' do
        user = create(:user, :fully_registered)
        generate_saml_response(user, saml_settings)

        expect(response).to_not be_redirect
      end
    end

    context 'with IALMAX and the identity is already verified' do
      let(:user) { create(:profile, :active, :verified).user }
      let(:pii) do
        Pii::Attributes.new_from_hash(
          first_name: 'Some',
          last_name: 'One',
          ssn: '666666666',
          zipcode: '12345',
        )
      end
      let(:this_authn_request) do
        ialmax_authnrequest = saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer,
            authn_context: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            authn_context_comparison: 'minimum',
          },
        )
        raw_req = CGI.unescape ialmax_authnrequest.split('SAMLRequest').last
        SamlIdp::Request.from_deflated_request(raw_req)
      end
      let(:asserter) do
        AttributeAsserter.new(
          user: user,
          service_provider: ServiceProvider.find_by(issuer: sp1_issuer),
          authn_request: this_authn_request,
          name_id_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          decrypted_pii: pii,
          user_session: {},
        )
      end
      let(:sign_in_flow) { :sign_in }

      before do
        stub_sign_in(user)
        session[:sign_in_flow] = sign_in_flow
        IdentityLinker.new(user, ServiceProvider.find_by(issuer: sp1_issuer)).link_identity(ial: 2)
        user.identities.last.update!(
          verified_attributes: %w[email given_name family_name social_security_number address],
        )
        allow(subject).to receive(:attribute_asserter) { asserter }

        if pii.present?
          Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(
            pii,
            user.active_profile.id,
          )
        end
      end

      it 'calls AttributeAsserter#build' do
        expect(asserter).to receive(:build).at_least(:once).and_call_original

        saml_get_auth(ialmax_settings)
      end

      it 'sets identity ial to 0' do
        saml_get_auth(ialmax_settings)
        expect(user.identities.last.ial).to eq(0)
      end

      it 'does not redirect the user to the IdV URL' do
        saml_get_auth(ialmax_settings)

        expect(response).to_not be_redirect
      end

      it 'contains verified attributes' do
        saml_get_auth(ialmax_settings)

        expect(xmldoc.attribute_node_for('address1')).to be_nil

        %w[first_name last_name ssn zipcode].each do |attr|
          node_value = xmldoc.attribute_value_for(attr)
          expect(node_value).to eq(pii[attr])
        end

        expect(xmldoc.attribute_value_for('verified_at')).to eq(
          user.active_profile.verified_at.iso8601,
        )
      end

      it 'tracks IAL2 authentication events' do
        stub_analytics

        allow(controller).to receive(:identity_needs_verification?).and_return(false)
        saml_get_auth(ialmax_settings)

        expect(@analytics).to have_logged_event(
          'SAML Auth Request', {
            authn_context: [Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF],
            requested_ial: 'ialmax',
            service_provider: sp1_issuer,
            force_authn: false,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
            user_fully_authenticated: true,
          }
        )
        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: true,
            errors: {},
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: ['http://idmanagement.gov/ns/assurance/ial/1'],
            authn_context_comparison: 'minimum',
            requested_ial: 'ialmax',
            service_provider: sp1_issuer,
            endpoint: "/api/saml/auth#{path_year}",
            idv: false,
            finish_profile: false,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
          ),
        )
        expect(@analytics).to have_logged_event(
          'SP redirect initiated',
          ial: 0,
          billed_ial: 2,
          sign_in_flow:,
          acr_values: Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF,
        )
      end

      context 'profile is not in session' do
        let(:pii) { nil }

        it 'redirects to password capture if profile is verified but not in session' do
          saml_get_auth(ialmax_settings)
          expect(response).to redirect_to capture_password_url
        end
      end
    end

    context 'authn_context is invalid' do
      let(:unknown_value) do
        'http://idmanagement.gov/ns/assurance/loa/5'
      end
      let(:authn_context) { unknown_value }

      before do
        stub_analytics

        saml_get_auth(
          saml_settings(
            overrides: { authn_context: },
          ),
        )
      end

      it 'renders an error page' do
        expect(controller).to render_template('saml_idp/auth/error')
        expect(response.status).to eq(400)
        expect(response.body).to include(t('errors.messages.unauthorized_authn_context'))
        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: false,
            errors: { authn_context: [t('errors.messages.unauthorized_authn_context')] },
            error_details: { authn_context: { unauthorized_authn_context: true } },
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: [unknown_value],
            authn_context_comparison: 'exact',
            service_provider: 'http://localhost:3000',
            request_signed: true,
            requested_ial: 'none',
            endpoint: "/api/saml/auth#{path_year}",
            idv: false,
            finish_profile: false,
            matching_cert_serial: saml_test_sp_cert_serial,
            unknown_authn_contexts: unknown_value,
          ),
        )
        expect(@analytics).to have_logged_event(
          :integration_errors_present,
          error_details: ['Unauthorized authentication context'],
          error_types: { saml_request_errors: true },
          event: :saml_auth_request,
          integration_exists: true,
          request_issuer: saml_settings.issuer,
        )
      end

      context 'there is also a valid authn_context' do
        let(:authn_context) do
          [
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            unknown_value,
          ]
        end

        it 'logs the unknown authn_context value' do
          expect(response.status).to eq(302)
          expect(@analytics).to have_logged_event(
            'SAML Auth Request',
            hash_including(
              unknown_authn_contexts: unknown_value,
            ),
          )
          expect(@analytics).to_not have_logged_event(
            :integration_errors_present,
          )
        end

        context 'when it includes the ReqAttributes AuthnContext' do
          let(:authn_context) do
            [
              Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF,
              Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
              unknown_value,
            ]
          end

          it 'logs the unknown authn_context value' do
            expect(response.status).to eq(302)
            expect(@analytics).to have_logged_event(
              'SAML Auth Request',
              hash_including(
                unknown_authn_contexts: unknown_value,
              ),
            )
          end
        end
      end
    end

    context 'authn_context scenarios' do
      let(:user) { create(:user, :fully_registered) }

      context 'authn_context is missing' do
        let(:auth_settings) { saml_settings(overrides: { authn_context: nil }) }

        it 'returns saml response with default AAL in authn context' do
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).
            to eq(Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF)
        end
      end

      context 'authn_context is defined by sp' do
        it 'returns default AAL authn_context when default AAL and IAL1 is requested' do
          auth_settings = saml_settings(
            overrides: { authn_context: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF },
          )
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).
            to eq(Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF)
        end

        it 'returns default AAL authn_context when IAL1 is requested' do
          auth_settings = saml_settings(
            overrides: { authn_context: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF },
          )
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).
            to eq(Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF)
        end

        it 'returns AAL2 authn_context when AAL2 is requested' do
          auth_settings = saml_settings(
            overrides: { authn_context: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF },
          )
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
        end

        it 'returns AAL3 authn_context when AAL3 is requested' do
          allow(controller).to receive(:user_session).and_return(
            auth_events: [
              { auth_method: TwoFactorAuthenticatable::AuthMethod::PIV_CAC, at: Time.zone.now },
            ],
          )
          user = create(:user, :with_piv_or_cac)
          auth_settings = saml_settings(
            overrides: { authn_context: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF },
          )
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).to eq(
            Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'returns AAL3-HSPD12 authn_context when AAL3-HSPD12 is requested' do
          allow(controller).to receive(:user_session).and_return(
            auth_events: [
              { auth_method: TwoFactorAuthenticatable::AuthMethod::PIV_CAC, at: Time.zone.now },
            ],
          )
          user = create(:user, :with_piv_or_cac)
          auth_settings = saml_settings(
            overrides: { authn_context: Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF },
          )
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).to eq(
            Saml::Idp::Constants::AAL3_HSPD12_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'returns AAL2-HSPD12 authn_context when AAL2-HSPD12 is requested' do
          allow(controller).to receive(:user_session).and_return(
            auth_events: [
              { auth_method: TwoFactorAuthenticatable::AuthMethod::PIV_CAC, at: Time.zone.now },
            ],
          )
          user = create(:user, :with_piv_or_cac)
          auth_settings = saml_settings(
            overrides: { authn_context: Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF },
          )
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).to eq(
            Saml::Idp::Constants::AAL2_HSPD12_AUTHN_CONTEXT_CLASSREF,
          )
        end

        it 'returns AAL2-phishing-resistant authn_context when AAL2-phishing-resistant requested' do
          allow(controller).to receive(:user_session).and_return(
            auth_events: [
              { auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN, at: Time.zone.now },
            ],
          )
          user = create(:user, :with_webauthn)
          auth_settings = saml_settings(
            overrides: {
              authn_context: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            },
          )
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).to eq(
            Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
          )
        end
      end
    end

    context 'with ForceAuthn' do
      let(:user) { create(:user, :fully_registered) }

      it 'signs user out if a session is active and sp_session[:final_auth_request] is falsey' do
        sign_in(user)
        generate_saml_response(user, saml_settings(overrides: { force_authn: true }))
        # would be 200 if the user's session persists
        expect(response.status).to eq(302)
        expect(response.location).to eq(root_url)
        expect(controller.session[:sp][:request_id]).to be_present
      end

      it 'skips signing out the user when sp_session[:final_auth_request] is true' do
        link_user_to_identity(user, true, saml_settings(overrides: { force_authn: true }))
        sign_in(user)
        controller.session[:sp] = { final_auth_request: true }
        saml_final_post_auth(saml_request(saml_settings(overrides: { force_authn: true })))
        expect(response).to_not be_redirect
        expect(response.status).to eq(200)
      end

      it 'sets sp_session[:final_auth_request] to false before returning' do
        sign_in(user)
        controller.session[:sp] = { final_auth_request: true }
        saml_final_post_auth(saml_request(saml_settings(overrides: { force_authn: true })))
        expect(session[:sp][:final_auth_request]).to be_falsey
      end

      it 'logs SAML Auth Request' do
        stub_analytics

        saml_get_auth(saml_settings(overrides: { force_authn: true }))

        expect(@analytics).to have_logged_event(
          'SAML Auth Request', {
            authn_context: request_authn_contexts,
            requested_ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            service_provider: 'http://localhost:3000',
            requested_aal_authn_context: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
            force_authn: true,
            user_fully_authenticated: false,
          }
        )
      end
    end

    context 'service provider is inactive' do
      it 'responds with an error page' do
        user = create(:user, :fully_registered)

        generate_saml_response(
          user,
          saml_settings(
            overrides: { issuer: 'http://localhost:3000/inactive_sp' },
          ),
        )

        expect(controller).to redirect_to sp_inactive_error_url
      end
    end

    context 'service provider is invalid' do
      it 'responds with an error page' do
        user = create(:user, :fully_registered)

        stub_analytics

        generate_saml_response(user, saml_settings(overrides: { issuer: 'invalid_provider' }))

        expect(controller).to render_template('saml_idp/auth/error')
        expect(response.status).to eq(400)
        expect(response.body).to include(t('errors.messages.unauthorized_service_provider'))
        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: false,
            errors: { service_provider: [t('errors.messages.unauthorized_service_provider')] },
            error_details: { service_provider: { unauthorized_service_provider: true } },
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: request_authn_contexts,
            authn_context_comparison: 'exact',
            request_signed: true,
            requested_ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            endpoint: "/api/saml/auth#{path_year}",
            idv: false,
            finish_profile: false,
          ),
        )
        expect(@analytics).to have_logged_event(
          :integration_errors_present,
          error_details: ['Unauthorized Service Provider'],
          error_types: { saml_request_errors: true },
          event: :saml_auth_request,
          integration_exists: false,
          request_issuer: 'invalid_provider',
        )
      end
    end

    context 'both service provider and authn_context are invalid' do
      it 'responds with an error page' do
        user = create(:user, :fully_registered)

        stub_analytics

        generate_saml_response(
          user,
          saml_settings(
            overrides: {
              issuer: 'invalid_provider',
              authn_context: 'http://idmanagement.gov/ns/assurance/loa/5',
            },
          ),
        )

        expect(controller).to render_template('saml_idp/auth/error')
        expect(response.status).to eq(400)
        expect(response.body).to include(t('errors.messages.unauthorized_authn_context'))
        expect(response.body).to include(t('errors.messages.unauthorized_service_provider'))
        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: false,
            errors: {
              service_provider: [t('errors.messages.unauthorized_service_provider')],
              authn_context: [t('errors.messages.unauthorized_authn_context')],
            },
            error_details: {
              authn_context: { unauthorized_authn_context: true },
              service_provider: { unauthorized_service_provider: true },
            },
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: ['http://idmanagement.gov/ns/assurance/loa/5'],
            authn_context_comparison: 'exact',
            request_signed: true,
            requested_ial: 'none',
            endpoint: "/api/saml/auth#{path_year}",
            idv: false,
            finish_profile: false,
          ),
        )
        expect(@analytics).to have_logged_event(
          :integration_errors_present,
          error_details: ['Unauthorized Service Provider', 'Unauthorized authentication context'],
          error_types: { saml_request_errors: true },
          event: :saml_auth_request,
          integration_exists: false,
          request_issuer: 'invalid_provider',
        )
      end
    end

    let(:second_cert_settings) do
      saml_settings.tap do |settings|
        settings.issuer = service_provider.issuer
        settings.certificate = File.read(Rails.root.join('certs', 'sp', 'saml_test_sp2.crt'))
        settings.private_key = OpenSSL::PKey::RSA.new(
          File.read(Rails.root + 'keys/saml_test_sp2.key'),
        ).to_pem
      end
    end

    context 'when service provider has no certs' do
      let(:service_provider) do
        create(
          :service_provider,
          certs: [],
          active: true,
        )
      end

      let(:settings) do
        saml_settings.tap do |settings|
          settings.issuer = service_provider.issuer
        end
      end

      it 'returns an error page' do
        user = create(:user, :fully_registered)
        stub_analytics

        generate_saml_response(user, settings)

        expect(response.body).to include(t('errors.messages.no_cert_registered'))
        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: false,
            errors: { service_provider: [t('errors.messages.no_cert_registered')] },
            error_details: { service_provider: { no_cert_registered: true } },
          ),
        )

        expect(@analytics).to have_logged_event(
          :integration_errors_present,
          error_details: ['Your service provider does not have a certificate registered.'],
          error_types: { saml_request_errors: true },
          event: :saml_auth_request,
          integration_exists: true,
          request_issuer: service_provider.issuer,
        )
      end

      context 'when service provider has block_encryption set to none' do
        before do
          service_provider.update!(block_encryption: 'none')
        end

        it 'is succesful' do
          user = create(:user, :fully_registered)
          stub_analytics

          generate_saml_response(user, settings)

          expect(response.body).to_not include(t('errors.messages.no_cert_registered'))
          expect(@analytics).to have_logged_event(
            'SAML Auth',
            hash_including(
              success: true,
            ),
          )
        end
      end
    end

    context 'service provider has multiple certs' do
      let(:service_provider) do
        create(
          :service_provider,
          certs: ['saml_test_sp2', 'saml_test_sp'],
          active: true,
        )
      end

      let(:first_cert_settings) do
        saml_settings.tap do |settings|
          settings.issuer = service_provider.issuer
        end
      end

      it 'encrypts the response to the right key' do
        user = create(:user, :fully_registered)
        generate_saml_response(user, second_cert_settings)

        expect(response).to_not be_redirect

        expect { xmldoc.saml_response(first_cert_settings) }.to raise_error

        response = xmldoc.saml_response(second_cert_settings)
        expect(response.decrypted_document).to be
      end
    end

    context 'service provider has the wrong certs' do
      let(:service_provider) do
        create(
          :service_provider,
          certs: ['saml_test_sp'],
          active: true,
        )
      end

      it 'does not blow up' do
        user = create(:user, :fully_registered)

        expect { generate_saml_response(user, second_cert_settings) }.to_not raise_error
      end
    end

    context 'POST to auth correctly stores SP in session' do
      let(:acr_values) do
        Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF +
          ' ' +
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
      end

      before do
        @user = create(:user, :fully_registered)
        @saml_request = saml_request(saml_settings)
        @post_request = saml_post_auth(@saml_request)
        @stored_request_url = @post_request.request.original_url +
                              '?SAMLRequest=' +
                              @saml_request
      end

      it 'stores SP metadata in session' do
        sp_request_id = ServiceProviderRequestProxy.last.uuid
        expect(session[:sp]).to eq(
          issuer: saml_settings.issuer,
          acr_values: acr_values,
          request_url: @stored_request_url.gsub('authpost', 'auth'),
          request_id: sp_request_id,
          requested_attributes: ['email'],
          vtr: nil,
        )
      end

      it 'correctly sets the request URL' do
        post :auth, params: { 'SAMLRequest' => @saml_request }
        session_request_url = session[:sp][:request_url]

        expect(session_request_url).to match(%r{/api/saml/auth\d{4}})
      end
    end

    context 'service provider is valid' do
      let(:acr_values) do
        Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF +
          ' ' +
          Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
      end

      before do
        @user = create(:user, :fully_registered)
        @saml_request = saml_get_auth(saml_settings)
      end

      it 'stores SP metadata in session' do
        sp_request_id = ServiceProviderRequestProxy.last.uuid

        expect(session[:sp]).to eq(
          issuer: saml_settings.issuer,
          acr_values: acr_values,
          request_url: @saml_request.request.original_url.gsub('authpost', 'auth'),
          request_id: sp_request_id,
          requested_attributes: ['email'],
          vtr: nil,
        )
      end

      context 'after successful assertion of ial1' do
        let(:user_identity) do
          @user.identities.find_by(service_provider: saml_settings.issuer)
        end

        before do
          sign_in(@user)
          saml_get_auth(saml_settings)
        end

        it 'does not delete SP metadata from session' do
          expect(session.key?(:sp)).to eq(true)
        end

        it 'does not create an identity record until the user confirms attributes ' do
          expect(user_identity).to be_nil
        end

        it 'redirects to verify attributes' do
          expect(response).to redirect_to sign_up_completed_url
        end

        it 'does not redirect after verifying attributes' do
          service_provider = build(:service_provider, issuer: saml_settings.issuer)
          IdentityLinker.new(@user, service_provider).link_identity(
            verified_attributes: ['email'],
          )
          saml_get_auth(saml_settings)

          expect(response).to_not redirect_to sign_up_completed_url
        end

        it 'redirects if verified attributes dont match requested attributes' do
          saml_get_auth(saml_settings)

          expect(response).to redirect_to sign_up_completed_url
        end
      end
    end

    describe 'SAML signature behavior' do
      let(:authn_requests_signed) { false }
      let(:matching_cert_serial) { nil }
      let(:service_provider) { ServiceProvider.find_by(issuer: auth_settings.issuer) }
      let(:user) { create(:user, :fully_registered) }

      let(:auth_settings) do
        saml_settings(
          overrides: {
            security: {
              authn_requests_signed:,
            },
          },
        )
      end

      before do
        stub_analytics
        IdentityLinker.new(user, service_provider).link_identity
      end

      context 'SAML request is not signed' do
        it 'notes that in the analytics event' do
          user.identities.last.update!(verified_attributes: ['email'])
          generate_saml_response(user, auth_settings)

          expect(response.status).to eq(200)
          expect(@analytics).to have_logged_event(
            'SAML Auth', hash_including(
              request_signed: false,
            )
          )
        end
      end

      context 'SAML request is signed' do
        let(:authn_requests_signed) { true }

        context 'Matching certificate' do
          it 'notes that in the analytics event' do
            user.identities.last.update!(verified_attributes: ['email'])
            generate_saml_response(user, auth_settings)

            expect(response.status).to eq(200)
            expect(@analytics).to have_logged_event(
              'SAML Auth', hash_including(
                request_signed: authn_requests_signed,
                matching_cert_serial: saml_test_sp_cert_serial,
              )
            )
          end

          context 'when request is using SHA1 as the signature method algorithm' do
            let(:auth_settings) do
              saml_settings(
                overrides: {
                  security: {
                    authn_requests_signed:,
                    signature_method: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha1',
                  },
                },
              )
            end

            context 'when the certificate matches' do
              it 'does not note that certs are different in the event' do
                user.identities.last.update!(verified_attributes: ['email'])
                generate_saml_response(user, auth_settings)

                expect(response.status).to eq(200)
                expect(@analytics).to have_logged_event(
                  'SAML Auth', hash_not_including(
                    certs_different: true,
                    sha256_matching_cert: matching_cert_serial,
                  )
                )
              end
            end

            context 'when the certificate does not match' do
              let(:wrong_cert) do
                OpenSSL::X509::Certificate.new(
                  Rails.root.join('certs', 'sp', 'saml_test_sp2.crt').read,
                )
              end

              before do
                service_provider.update!(certs: [wrong_cert, saml_test_sp_cert])
              end

              it 'notes that certs are different in the event' do
                user.identities.last.update!(verified_attributes: ['email'])
                generate_saml_response(user, auth_settings)

                expect(response.status).to eq(200)
                expect(@analytics).to have_logged_event(
                  'SAML Auth', hash_including(
                    certs_different: true,
                    sha256_matching_cert: wrong_cert.serial.to_s,
                  )
                )
              end
            end
          end

          context 'when request is using SHA1 as the digest method algorithm' do
            let(:auth_settings) do
              saml_settings(
                overrides: {
                  security: {
                    authn_requests_signed:,
                    digest_method: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha1',
                  },
                },
              )
            end

            it 'notes an error in the event' do
              user.identities.last.update!(verified_attributes: ['email'])
              generate_saml_response(user, auth_settings)

              expect(response.status).to eq(200)
              expect(@analytics).to have_logged_event(
                'SAML Auth', hash_including(
                  request_signed: authn_requests_signed,
                  cert_error_details: [
                    {
                      cert: '16692258094164984098',
                      error_code: :fingerprint_mismatch,
                    },
                    {
                      cert: '14834808178619537243', error_code: :fingerprint_mismatch
                    },
                  ],
                )
              )
            end
          end

          context 'Certificate sig validation fails because of namespace bug' do
            let(:request_sp) { double }

            before do
              service_provider.update(certs: ['sp_sinatra_demo', 'saml_test_sp'])
              allow_any_instance_of(
                SamlIdp::ServiceProvider,
              ).to receive(:matching_cert).and_return nil
            end

            it 'notes that in the analytics event' do
              user.identities.last.update!(verified_attributes: ['email'])
              generate_saml_response(user, auth_settings)

              expect(response.status).to eq(200)
              expect(@analytics).to have_logged_event(
                'SAML Auth', hash_including(
                  request_signed: authn_requests_signed,
                )
              )
            end
          end
        end

        context 'Certificate does not match' do
          let(:service_provider) do
            create(
              :service_provider,
              certs: ['saml_test_sp'],
              active: true,
              assertion_consumer_logout_service_url: 'https://example.com',
            )
          end

          let(:auth_settings) do
            saml_settings(
              overrides: {
                certificate: File.read(Rails.root.join('certs', 'sp', 'saml_test_sp2.crt')),
                issuer: service_provider.issuer,
                private_key: OpenSSL::PKey::RSA.new(
                  File.read(Rails.root + 'keys/saml_test_sp2.key'),
                ).to_pem,
                security: {
                  authn_requests_signed:,
                },
              },
            )
          end

          it 'notes that in the analytics event' do
            user.identities.last.update!(verified_attributes: ['email'])
            generate_saml_response(user, auth_settings)
            cert_error_details = [
              {
                cert: saml_test_sp_cert_serial,
                error_code: :fingerprint_mismatch,
              },
            ]

            expect(response.status).to eq(200)
            expect(@analytics).to have_logged_event(
              'SAML Auth', hash_including(
                request_signed: authn_requests_signed,
                cert_error_details:,
              )
            )
          end
        end
      end
    end

    context 'cert element in SAML request is blank' do
      let(:user) { create(:user, :fully_registered) }
      let(:service_provider) { build(:service_provider, issuer: 'http://localhost:3000') }

      before do
        stub_analytics
      end

      # the RubySAML library won't let us pass an empty string in as the certificate
      # element, so this test substitutes a SAMLRequest that has that element blank
      let(:blank_cert_element_req) do
        <<-XML.gsub(/^[\s]+|[\s]+\n/, '')
          <?xml version="1.0"?>
          <samlp:AuthnRequest xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion" xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" AssertionConsumerServiceURL="http://localhost:3000/test/saml/decode_assertion" Destination="http://www.example.com/api/saml/auth2024" ID="_6b15011e-abfe-4c55-925f-6a5b3872a64c" IssueInstant="2024-01-11T18:03:38Z" Version="2.0">
            <saml:Issuer>http://localhost:3000</saml:Issuer>
            <ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
              <ds:SignedInfo>
                <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
                <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
                <ds:Reference URI="#_6b15011e-abfe-4c55-925f-6a5b3872a64c">
                  <ds:Transforms>
                    <ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
                    <ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#">
                      <ec:InclusiveNamespaces xmlns:ec="http://www.w3.org/2001/10/xml-exc-c14n#" PrefixList="#default samlp saml ds xs xsi md"/>
                    </ds:Transform>
                  </ds:Transforms>
                  <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
                  <ds:DigestValue>aoHPDDUZTRSIVsbuE954QKbo6StafYvbVUPU+p33m8E=</ds:DigestValue>
                </ds:Reference>
              </ds:SignedInfo>
              <ds:SignatureValue>JH0VD0SLKawSS9tnlUxUL2fYVCza4MT6L79aRiKQi56+arGfnPHZ21cIYOEHxDn2xIg6EV6tda+WwOP9WTrsuqJLAfTWLz9Ah2A8ukITIOYED5WboiodLr5sjkr4HFKwRjERtLycLaxDt8Ya9tHQa5mOjln8yIWFDLdf89jnXaTM9gReq2k1MpI3YlhIYHJMALY5NxbOPTTmWeXdiUUYH/Irq2jzXrI+2ruyCZt8Xpo9tfosFGnoTGFkeK7sWOmndle2WqRE29k4S582JJtXgi4A8JDGw0KK8zM4JttxpK+DbowN8wJ4gWpgRppkBi5e6JiV4W0DNgZC72WHjXULQg==</ds:SignatureValue>
              <ds:KeyInfo>
                <ds:X509Data>
                  <ds:X509Certificate></ds:X509Certificate>
                </ds:X509Data>
              </ds:KeyInfo>
            </ds:Signature>
            <samlp:NameIDPolicy AllowCreate="true" Format="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"/>
            <samlp:RequestedAuthnContext Comparison="exact">
          <saml:AuthnContextClassRef>urn:gov:gsa:ac:classes:sp:PasswordProtectedTransport:duo</saml:AuthnContextClassRef>
            </samlp:RequestedAuthnContext>
          </samlp:AuthnRequest>
        XML
      end
      let(:deflated_encoded_req) do
        Base64.encode64(Zlib::Deflate.deflate(blank_cert_element_req, 9)[2..-5])
      end

      before do
        IdentityLinker.new(user, service_provider).link_identity
        user.identities.last.update!(verified_attributes: ['email'])
        expect(CGI).to receive(:unescape).and_return deflated_encoded_req
      end

      it 'notes it in the analytics event' do
        generate_saml_response(user, saml_settings)

        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: false,
            errors: { service_provider: ['We cannot detect a certificate in your request.'] },
            error_details: { service_provider: { blank_cert_element_req: true } },
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: [Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF],
            authn_context_comparison: 'exact',
            service_provider: 'http://localhost:3000',
            request_signed: true,
            requested_ial: 'none',
            endpoint: "/api/saml/auth#{path_year}",
            idv: false,
            finish_profile: false,
          ),
        )
      end

      it 'returns a 400' do
        generate_saml_response(user, saml_settings)
        expect(controller).to render_template('saml_idp/auth/error')
        expect(response.status).to eq(400)
        expect(response.body).to include(t('errors.messages.blank_cert_element_req'))
      end
    end

    context 'no IAL explicitly requested' do
      let(:user) { create(:user, :fully_registered) }

      before do
        stub_analytics
      end

      it 'notes that in the analytics event' do
        auth_settings = saml_settings(
          overrides: { authn_context: [
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
          ] },
        )
        service_provider = build(:service_provider, issuer: auth_settings.issuer)
        IdentityLinker.new(user, service_provider).link_identity
        user.identities.last.update!(verified_attributes: ['email'])
        generate_saml_response(user, auth_settings)

        expect(response.status).to eq(200)

        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: true,
            errors: {},
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: [Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF],
            authn_context_comparison: 'exact',
            requested_ial: 'none',
            service_provider: 'http://localhost:3000',
            endpoint: "/api/saml/auth#{path_year}",
            idv: false,
            finish_profile: false,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
          ),
        )
      end
    end

    describe 'NameID format' do
      let(:user) { create(:user, :fully_registered) }
      let(:subject_element) { xmldoc.subject_nodeset[0] }
      let(:name_id) { subject_element.at('//ds:NameID', ds: Saml::XML::Namespaces::ASSERTION) }
      let(:auth_settings) { saml_settings(overrides: { name_identifier_format: }) }
      let(:name_identifier_format) { nil }
      let(:email_allowed) { nil }
      let(:use_legacy_name_id_behavior) { nil }

      before do
        stub_analytics
        service_provider = ServiceProvider.find_by(issuer: auth_settings.issuer)
        IdentityLinker.new(user, service_provider).link_identity
        service_provider.update!(
          use_legacy_name_id_behavior:,
          email_nameid_format_allowed: email_allowed,
        )
      end

      shared_examples_for 'sends the UUID' do |requested_nameid_format|
        it 'sends the UUID' do
          generate_saml_response(user, auth_settings)

          expect(response.status).to eq(200)
          expect(name_id.attributes['Format'].value).
            to eq(Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT)
          expect(name_id.children.first.to_s).to eq(user.last_identity.uuid)
          expect(@analytics).to have_logged_event(
            'SAML Auth',
            hash_including(
              {
                nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
                requested_nameid_format: requested_nameid_format,
                success: true,
              }.compact,
            ),
          )
        end
      end

      shared_examples_for 'sends the email' do |requested_nameid_format|
        it 'sends the email' do
          generate_saml_response(user, auth_settings)

          expect(response.status).to eq(200)
          expect(name_id.attributes['Format'].value).
            to eq(Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL)
          expect(name_id.children.first.to_s).to eq(user.email)
          expect(@analytics).to have_logged_event(
            'SAML Auth',
            hash_including(
              nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL,
              requested_nameid_format: requested_nameid_format,
              success: true,
            ),
          )
        end
      end

      shared_examples_for 'returns an unauthorized nameid error' do |requested_nameid_format|
        it 'returns an error' do
          generate_saml_response(user, auth_settings)

          expect(controller).to render_template('saml_idp/auth/error')
          expect(response.status).to eq(400)
          expect(response.body).to include(t('errors.messages.unauthorized_nameid_format'))
          expect(@analytics).to have_logged_event(
            'SAML Auth',
            hash_including(
              nameid_format: requested_nameid_format,
              requested_nameid_format: requested_nameid_format,
              success: false,
            ),
          )
        end
      end

      context 'when the NameID format has the value "unspecified"' do
        let(:name_identifier_format) { Saml::Idp::Constants::NAME_ID_FORMAT_UNSPECIFIED }

        context 'when the service provider is not configured with use_legacy_name_id_behavior' do
          let(:use_legacy_name_id_behavior) { false }

          it_behaves_like 'sends the UUID', Saml::Idp::Constants::NAME_ID_FORMAT_UNSPECIFIED
        end

        context 'when the service provider is configured with use_legacy_name_id_behavior' do
          let(:use_legacy_name_id_behavior) { true }

          it 'sends the id, not the UUID' do
            generate_saml_response(user, auth_settings)

            expect(response.status).to eq(200)

            expect(name_id.attributes['Format'].value).
              to eq(Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT)

            expect(name_id.children.first.to_s).to eq(user.id.to_s)
          end
        end
      end

      context 'when the NameID format is missing' do
        let(:name_identifier_format) { nil }

        context 'when the service provider is not configured with use_legacy_name_id_behavior' do
          let(:use_legacy_name_id_behavior) { false }

          it_behaves_like 'sends the UUID', nil
        end

        context 'when the service provider is configured with use_legacy_name_id_behavior' do
          let(:use_legacy_name_id_behavior) { true }

          it_behaves_like 'sends the UUID', nil
        end
      end

      context 'when the NameID format is "persistent"' do
        let(:name_identifier_format) { Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT }

        it_behaves_like 'sends the UUID', Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT
      end

      context 'when the NameID format is "email"' do
        let(:name_identifier_format) { Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL }

        context 'when the service provider is not allowed to use email' do
          let(:email_allowed) { false }

          it_behaves_like 'returns an unauthorized nameid error',
                          Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        end

        context 'when the service provider is allowed to use email' do
          let(:email_allowed) { true }

          it_behaves_like 'sends the email', Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL
        end
      end

      context 'when the NameID format is an unsupported value' do
        let(:name_identifier_format) { 'urn:oasis:names:tc:SAML:1.1:nameid-format:transient' }
        let(:use_legacy_name_id_behavior) { nil }

        context 'when the service provider is not configured with use_legacy_name_id_behavior' do
          # This should always return an error. An aborted attempt was made to fix this
          # with 30cb0f374
          let(:use_legacy_name_id_behavior) { false }

          context 'when the service provider is not allowed to use email' do
            let(:email_allowed) { false }

            it_behaves_like 'sends the UUID', 'urn:oasis:names:tc:SAML:1.1:nameid-format:transient'
          end

          context 'when the service provider is allowed to use email' do
            let(:email_allowed) { true }

            it_behaves_like 'sends the email', 'urn:oasis:names:tc:SAML:1.1:nameid-format:transient'
          end
        end

        context 'when the service provider is configured with use_legacy_name_id_behavior' do
          let(:use_legacy_name_id_behavior) { true }

          it 'sends the id, not the UUID' do
            generate_saml_response(user, auth_settings)

            expect(response.status).to eq(200)

            expect(name_id.attributes['Format'].value).
              to eq(Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT)

            expect(name_id.children.first.to_s).to eq(user.id.to_s)
          end
        end
      end
    end

    describe 'HEAD /api/saml/auth', type: :request do
      it 'responds with "403 Forbidden"' do
        head '/api/saml/auth2024?SAMLRequest=bang!'

        expect(response.status).to eq(403)
      end
    end

    context 'with missing SAMLRequest params' do
      it 'responds with "403 Forbidden"' do
        get :auth

        expect(response.status).to eq(403)
      end
    end

    context 'with invalid SAMLRequest param' do
      it 'responds with "403 Forbidden"' do
        get :auth

        expect(response.status).to eq(403)
      end
    end

    context 'when user is not logged in' do
      it 'redirects the user to the SP landing page with the request_id in the session' do
        saml_get_auth(saml_settings)
        sp_request_id = ServiceProviderRequestProxy.last.uuid
        expect(response).to redirect_to new_user_session_path
        expect(session[:sp][:request_id]).to eq sp_request_id
      end

      it 'logs SAML Auth Request but does not log SAML Auth' do
        stub_analytics

        saml_get_auth(saml_settings)

        expect(@analytics).to have_logged_event(
          'SAML Auth Request', {
            authn_context: request_authn_contexts,
            requested_ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            service_provider: 'http://localhost:3000',
            requested_aal_authn_context: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
            force_authn: false,
            user_fully_authenticated: false,
          }
        )
      end
    end

    context 'after signing in' do
      it 'does not call IdentityLinker' do
        user = create(:user, :fully_registered)
        linker = instance_double(IdentityLinker)

        expect(IdentityLinker).to_not receive(:new)
        expect(linker).to_not receive(:link_identity)

        generate_saml_response(user, link: false)
      end
    end

    context 'SAML Response' do
      let(:issuer) { xmldoc.issuer_nodeset[0] }
      let(:status) { xmldoc.status[0] }
      let(:status_code) { xmldoc.status_code[0] }
      let(:user) { create(:user, :fully_registered) }

      before do
        generate_saml_response(user, saml_settings)
      end

      it 'returns a valid xml document' do
        expect(xmldoc.saml_document.validate).to be(nil)
        expect(xmldoc.saml_response(saml_settings).is_valid?).to eq(true)
      end

      # a <saml:Issuer> element, which contains the unique identifier of the identity provider
      it 'includes an Issuer element inherited from the base URL' do
        expect(issuer.name).to eq('Issuer')
        expect(issuer.namespace.href).to eq(Saml::XML::Namespaces::ASSERTION)
        expect(issuer.text).to eq("https://#{IdentityConfig.store.domain_name}/api/saml")
      end

      it 'includes a Status element with a StatusCode child element' do
        # https://msdn.microsoft.com/en-us/library/hh269633.aspx
        expect(status.name).to eq('Status')
      end

      it 'includes the required StatusCode' do
        # https://msdn.microsoft.com/en-us/library/hh269642.aspx
        expect(status.children.include?(status_code)).to be(true)
        expect(status_code.name).to eq('StatusCode')
      end

      it 'returns a Success status code' do
        # https://msdn.microsoft.com/en-us/library/hh269642.aspx
        expect(status_code['Value']).to eq(Saml::XML::Namespaces::Statuses::SUCCESS)
      end

      it 'sets correct CSP config that includes any custom app scheme uri from SP redirect_uris' do
        form_action = response.request.content_security_policy.form_action
        csp_array = ["'self'", 'http://localhost:3000', 'x-example-app:']
        expect(form_action).to match_array(csp_array)
      end

      # http://en.wikipedia.org/wiki/SAML_2.0#SAML_2.0_Assertions
      context 'Assertion' do
        let(:assertion) { xmldoc.response_assertion_nodeset[0] }

        it 'includes the xmlns:saml attribute in the element' do
          # JJG NOTE: should this be xmlns:saml? See example block at:
          # http://en.wikipedia.org/wiki/SAML_2.0#SAML_2.0_Assertions
          # expect(assertion.namespaces['xmlns:saml'])
          #   .to eq('urn:oasis:names:tc:SAML:2.0:assertion')
          expect(assertion.namespace.href).to eq(Saml::XML::Namespaces::ASSERTION)
        end

        it 'includes an ID attribute with a valid UUID' do
          expect(Idp::Constants::UUID_REGEX.match?(assertion['ID'][1..-1])).to eq(true)
          expect(assertion['ID']).to eq "_#{user.last_identity.session_uuid}"
        end

        it 'includes an IssueInstant attribute with a timestamp' do
          # JJG NOTE: look up in spec to check the proper format to test
          # against. For now I'm using a regex against what we're using
          # '2015-05-08T01:48:02Z'
          expect(assertion['IssueInstant']).to match(/\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ/)
        end

        it 'includes an Version attribute set to v2.0' do
          expect(assertion['Version']).to eq('2.0')
        end
      end

      # a <ds:Signature> element, which contains an integrity-preserving
      # digital signature (not shown) over the <saml:Assertion> element
      context 'ds:Signature' do
        let(:signature) { xmldoc.signature }

        it 'includes the ds:Signature element with the signature namespace' do
          # JJG NOTE: should this be xmlds:ds? See example block at:
          # http://en.wikipedia.org/wiki/SAML_2.0#SAML_2.0_Assertions
          # expect(signature.namespaces['xmlns:ds']).to eq('http://www.w3.org/2000/09/xmldsig#')
          expect(signature.name).to eq('Signature')
          expect(signature.namespace.href).to eq(Saml::XML::Namespaces::SIGNATURE)
        end

        it 'includes a KeyInfo element' do
          element = signature.at(
            '//ds:KeyInfo',
            ds: Saml::XML::Namespaces::SIGNATURE,
          )

          expect(element.name).to eq('KeyInfo')
        end

        it 'includes a X509Data element' do
          element = signature.at(
            '//ds:X509Data',
            ds: Saml::XML::Namespaces::SIGNATURE,
          )

          expect(element.name).to eq('X509Data')
        end

        it 'includes a X509Certificate element' do
          element = signature.at(
            '//ds:X509Certificate',
            ds: Saml::XML::Namespaces::SIGNATURE,
          )

          expect(element.name).to eq('X509Certificate')
        end

        it 'includes the saml cert from the certs folder' do
          element = signature.at(
            '//ds:X509Certificate',
            ds: Saml::XML::Namespaces::SIGNATURE,
          )

          crt = AppArtifacts.store.saml_2024_cert
          expect(element.text).to eq(crt.split("\n")[1...-1].join("\n").delete("\n"))
        end

        it 'includes a SignatureValue element' do
          element = signature.at(
            '//ds:Signature/ds:SignatureValue',
            ds: Saml::XML::Namespaces::SIGNATURE,
          )

          expect(element.name).to eq('SignatureValue')
          expect(element.text).to be_present
        end
      end

      # http://en.wikipedia.org/wiki/XML_Signature
      context 'SignedInfo' do
        let(:signed_info) { xmldoc.signed_info_nodeset[0] }

        it 'includes a SignedInfo element' do
          expect(signed_info.name).to eq('SignedInfo')
        end

        it 'includes a CanonicalizationMethod element' do
          element = xmldoc.signature_canon_method_nodeset[0]

          expect(element.name).to eq('CanonicalizationMethod')
          expect(element['Algorithm']).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
        end

        it 'includes a SignatureMethod element specifying rsa-sha256' do
          element = xmldoc.signature_method_nodeset[0]

          expect(element.name).to eq('SignatureMethod')
          expect(element['Algorithm']).to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
        end

        it 'includes a DigestMethod element' do
          element = xmldoc.digest_method_nodeset[0]

          expect(element.name).to eq('DigestMethod')
          expect(element['Algorithm']).to eq('http://www.w3.org/2001/04/xmlenc#sha256')
        end

        it 'has valid signature' do
          expect(xmldoc.saml_document.valid_signature?(idp_fingerprint)).to eq(true)
        end

        context 'Reference' do
          let(:reference) do
            signed_info.at(
              '//ds:SignedInfo/ds:Reference',
              ds: Saml::XML::Namespaces::SIGNATURE,
            )
          end

          it 'includes a Reference element' do
            expect(reference.name).to eq('Reference')
          end

          it 'includes a URI attribute' do
            expect(Idp::Constants::UUID_REGEX.match?(reference['URI'][2..-1])).to eq(true)
          end
        end
      end

      context 'Transforms' do
        let(:transforms) { xmldoc.transforms_nodeset[0] }

        it 'includes a Transforms element specifying multiple transformation algorithms' do
          expect(transforms.name).to eq('Transforms')
        end

        it 'includes a Transform specifying the Schema for XML Signatures' do
          algorithm = 'http://www.w3.org/2000/09/xmldsig#enveloped-signature'

          expect(transforms.children.include?(xmldoc.transform(algorithm))).to be(true)
          expect(xmldoc.transform(algorithm)['Algorithm']).to eq(algorithm)
        end

        it 'includes a Transform specifying the Canonical XML serialization' do
          algorithm = 'http://www.w3.org/2001/10/xml-exc-c14n#'

          expect(transforms.children.include?(xmldoc.transform(algorithm))).to be(true)
          expect(xmldoc.transform(algorithm)['Algorithm']).to eq(algorithm)
        end
      end

      # a <saml:Subject> element, which identifies the authenticated
      # principal (but in this case the identity of the principal is
      # hidden behind an opaque transient identifier, for reasons of privacy)
      context 'Subject' do
        let(:subject) { xmldoc.subject_nodeset[0] }

        it 'has a saml:Subject element' do
          expect(subject).to_not be_nil
        end

        context 'NameID' do
          let(:name_id) { subject.at('//ds:NameID', ds: Saml::XML::Namespaces::ASSERTION) }

          it 'has a saml:NameID element' do
            expect(name_id).to_not be_nil
          end

          it 'has a format attribute specifying the email format' do
            expect(name_id.attributes['Format'].value).
              to eq('urn:oasis:names:tc:SAML:2.0:nameid-format:persistent')
          end

          it 'has the UUID of the user making the AuthN Request' do
            expect(name_id.children.first.to_s).to eq(user.last_identity.uuid)
          end
        end

        context 'SubjectConfirmation' do
          let(:subject_confirmation) do
            subject.at(
              '//ds:SubjectConfirmation',
              ds: 'urn:oasis:names:tc:SAML:2.0:assertion',
            )
          end

          it 'has a SubjectConfirmation element' do
            expect(subject_confirmation).to_not be_nil
          end

          it 'has a method attribute specifying the bearer method' do
            expect(subject_confirmation.attributes['Method']).to_not be_nil
          end

          context 'SubjectConfirmationData' do
            let(:subject_confirmation_data) do
              subject_confirmation.at(
                '//ds:SubjectConfirmationData',
                ds: 'urn:oasis:names:tc:SAML:2.0:assertion',
              )
            end

            let(:attributes) do
              subject_confirmation_data.attributes.map { |c| c[0] }
            end

            it 'has a SubjectConfirmationData element' do
              expect(subject_confirmation_data).to_not be_nil
            end

            it 'has an InResponseTo attribute' do
              expect(attributes).to include('InResponseTo')

              expect(subject_confirmation_data.attributes['InResponseTo'].value).to_not be_nil
            end

            it 'has a NotOnOrAfter attribute' do
              expect(attributes).to include('NotOnOrAfter')

              expect(subject_confirmation_data.attributes['NotOnOrAfter'].value).to_not be_nil
            end

            it 'has a Recipient attribute' do
              expect(attributes).to include('Recipient')

              expect(subject_confirmation_data.attributes['Recipient'].value).to_not be_nil
            end
          end
        end
      end

      # a <saml:Conditions> element, which gives the conditions under which
      # the assertion is to be considered valid
      context 'Conditions' do
        let(:subject) { xmldoc.conditions_nodeset[0] }

        it 'has a saml:Conditions element' do
          expect(subject).to_not be_nil
        end

        it 'has a NotBefore attribute' do
          expect(subject.attributes['NotBefore'].value).to_not be_nil
        end

        it 'has a NotOnOrAfter attribute' do
          expect(subject.attributes['NotOnOrAfter'].value).to_not be_nil
        end
      end

      # a <saml:AuthnStatement> element, which describes the act of
      # authentication at the identity provider
      context 'AuthnStatement' do
        let(:subject) { xmldoc.assertion_statement_node }

        it 'has a saml:AuthnStatement element' do
          expect(subject).to_not be_nil
        end

        it 'has an AuthnInstant attribute' do
          expect(subject.attributes['AuthnInstant'].value).to_not be_nil
        end

        it 'has a SessionIndex attribute' do
          expect(subject.attributes['SessionIndex'].value).to_not be_nil
        end
      end

      context 'AuthnContext' do
        let(:subject) do
          xmldoc.saml_document.at(
            '//ds:AuthnStatement/ds:AuthnContext',
            ds: Saml::XML::Namespaces::ASSERTION,
          )
        end

        it 'has a saml:AuthnContext element' do
          expect(subject).to_not be_nil
        end

        context 'AuthnContextClassRef' do
          let(:subject) do
            xmldoc.saml_document.at(
              '//ds:AuthnStatement/ds:AuthnContext/ds:AuthnContextClassRef',
              ds: Saml::XML::Namespaces::ASSERTION,
            )
          end

          it 'has a saml:AuthnContextClassRef element' do
            expect(subject).to_not be_nil
          end

          it 'has contents set to default AAL' do
            expect(subject.content).to eq Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF
          end
        end
      end

      # a <saml:AttributeStatement> element, which asserts a multi-valued
      # attribute associated with the authenticated principal
      context 'saml:AttributeStatement' do
        it 'includes the saml:AttributeStatement element' do
          attribute_statement = xmldoc.saml_document.at(
            '//*/saml:AttributeStatement',
            saml: Saml::XML::Namespaces::ASSERTION,
          )

          expect(attribute_statement.class).to eq(Nokogiri::XML::Element)
          expect(attribute_statement.name).to eq('AttributeStatement')
        end

        it 'includes the email Attribute element' do
          email = xmldoc.attribute_node_for('email')

          expect(email.name).to eq('Attribute')
          expect(email['Name']).to eq('email')
          expect(email['NameFormat']).to eq('urn:oasis:names:tc:SAML:2.0:attrname-format:basic')
          expect(email['FriendlyName']).to eq('email')
        end

        it 'includes the uuid Attribute element' do
          uuid = xmldoc.attribute_node_for('uuid')

          expect(uuid.name).to eq('Attribute')
          expect(uuid['Name']).to eq('uuid')
          expect(uuid['NameFormat']).to eq('urn:oasis:names:tc:SAML:2.0:attrname-format:basic')
          expect(uuid['FriendlyName']).to eq('uuid')
        end

        it 'does not include the phone Attribute element when authn_context is IAL1' do
          phone = xmldoc.phone_number

          expect(phone).to be_nil
        end
      end
    end

    context 'user requires ID verification' do
      it 'tracks the authentication and IdV redirection event' do
        stub_analytics
        stub_sign_in
        allow(controller).to receive(:remember_device_expired_for_sp?).and_return(false)
        allow(controller).to receive(:identity_needs_verification?).and_return(true)
        allow(controller).to receive(:saml_request).and_return(FakeSamlRequest.new)
        allow(controller).to receive(:saml_request_id).
          and_return(SecureRandom.uuid)
        stub_requested_attributes

        get :auth, params: { path_year: path_year }

        expect(@analytics).to have_logged_event(
          'SAML Auth Request', {
            authn_context: [
              Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            ],
            requested_ial: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            service_provider: 'http://localhost:3000',
            requested_aal_authn_context: Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
            force_authn: false,
            request_signed: false,
            user_fully_authenticated: true,
          }
        )
        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: true,
            errors: {},
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: [
              Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF,
              Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            ],
            authn_context_comparison: 'exact',
            requested_ial: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
            service_provider: 'http://localhost:3000',
            endpoint: "/api/saml/auth#{path_year}",
            idv: true,
            finish_profile: false,
            request_signed: false,
          ),
        )
      end
    end

    def stub_requested_attributes
      service_provider = ServiceProvider.find_by(issuer: 'http://localhost:3000')
      service_provider.ial = 2
      service_provider.save
      request_parser = instance_double(SamlRequestParser)
      expect(SamlRequestParser).to receive(:new).
        and_return(request_parser)
      allow(request_parser).to receive(:requested_attributes).and_return([:email])
    end

    context 'user is not redirected to IdV' do
      it 'tracks the authentication without IdV redirection event' do
        user = create(:user, :fully_registered)
        stub_analytics
        session[:sign_in_flow] = :sign_in
        allow(controller).to receive(:identity_needs_verification?).and_return(false)

        generate_saml_response(user)

        expect(@analytics).to have_logged_event(
          'SAML Auth Request', {
            authn_context: request_authn_contexts,
            requested_ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            service_provider: 'http://localhost:3000',
            requested_aal_authn_context: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            force_authn: false,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
            user_fully_authenticated: true,
          }
        )
        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: true,
            errors: {},
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: request_authn_contexts,
            authn_context_comparison: 'exact',
            requested_ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            service_provider: 'http://localhost:3000',
            endpoint: "/api/saml/auth#{path_year}",
            idv: false,
            finish_profile: false,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
          ),
        )
        expect(@analytics).to have_logged_event(
          'SP redirect initiated',
          ial: 1,
          billed_ial: 1,
          sign_in_flow: :sign_in,
          acr_values: [
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          ].join(' '),
        )
      end
    end

    context 'user has not finished verifying profile' do
      it 'tracks the authentication with finish_profile==true' do
        user = create(:user, :fully_registered)
        stub_analytics
        session[:sign_in_flow] = :sign_in
        allow(controller).to receive(:identity_needs_verification?).and_return(false)
        allow(controller).to receive(:user_has_pending_profile?).and_return(true)

        generate_saml_response(user)

        expect(@analytics).to have_logged_event(
          'SAML Auth Request', {
            authn_context: request_authn_contexts,
            requested_ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            service_provider: 'http://localhost:3000',
            requested_aal_authn_context: Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            force_authn: false,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
            user_fully_authenticated: true,
          }
        )
        expect(@analytics).to have_logged_event(
          'SAML Auth',
          hash_including(
            success: true,
            errors: {},
            nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
            authn_context: request_authn_contexts,
            authn_context_comparison: 'exact',
            requested_ial: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            service_provider: 'http://localhost:3000',
            endpoint: "/api/saml/auth#{path_year}",
            idv: false,
            finish_profile: true,
            request_signed: true,
            matching_cert_serial: saml_test_sp_cert_serial,
          ),
        )
        expect(@analytics).to have_logged_event(
          'SP redirect initiated',
          ial: 1,
          billed_ial: 1,
          sign_in_flow: :sign_in,
          acr_values: [
            Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF,
            Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          ].join(' '),
        )
      end
    end
  end

  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :disable_caching,
        :store_saml_request,
        :validate_and_create_saml_request_object,
        :validate_service_provider_and_authn_context,
      )
    end
  end

  describe '#external_saml_request' do
    it 'returns false for malformed referer' do
      request.env['HTTP_REFERER'] = '{{<script>console.log()</script>'
      expect(subject.external_saml_request?).to eq false
    end

    it 'returns false for empty referer' do
      expect(subject.external_saml_request?).to eq false
    end
  end
end
