require 'rails_helper'

describe SamlIdpController do
  include SamlAuthHelper

  let(:aal_context_enabled) { 'false' }

  before do
    # All the tests here were written prior to the interstitial
    # authorization confirmation page so let's force the system
    # to skip past that page
    allow(controller).to receive(:auth_count).and_return(2)
    allow(AppConfig.env).to receive(:aal_authn_context_enabled).and_return(aal_context_enabled)
  end

  render_views

  describe '/api/saml/logout' do
    it 'tracks the event when idp initiated' do
      stub_analytics

      result = { sp_initiated: false, oidc: false, saml_request_valid: true }
      expect(@analytics).to receive(:track_event).with(Analytics::LOGOUT_INITIATED, result)

      delete :logout
    end

    it 'tracks the event when sp initiated' do
      allow(controller).to receive(:saml_request).and_return(FakeSamlLogoutRequest.new)
      stub_analytics

      result = { sp_initiated: true, oidc: false, saml_request_valid: true }
      expect(@analytics).to receive(:track_event).with(Analytics::LOGOUT_INITIATED, result)

      delete :logout, params: { SAMLRequest: 'foo' }
    end

    it 'tracks the event when the saml request is invalid' do
      stub_analytics

      result = { sp_initiated: true, oidc: false, saml_request_valid: false }
      expect(@analytics).to receive(:track_event).with(Analytics::LOGOUT_INITIATED, result)

      delete :logout, params: { SAMLRequest: 'foo' }
    end
  end

  describe '/api/saml/metadata' do
    before do
      get :metadata
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
    let(:xmldoc) { SamlResponseDoc.new('controller', 'response_assertion', response) }
    let(:aal_level) { AppConfig.env.aal_authn_context_enabled == 'true' ? 2 : nil }

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
        raw_req = CGI.unescape ial2_authnrequest.split('SAMLRequest').last
        SamlIdp::Request.from_deflated_request(raw_req)
      end
      let(:asserter) do
        AttributeAsserter.new(
          user: user,
          service_provider: ServiceProvider.from_issuer(sp1_ial2_saml_settings.issuer),
          authn_request: this_authn_request,
          name_id_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          decrypted_pii: pii,
          user_session: {},
        )
      end

      before do
        stub_sign_in(user)
        IdentityLinker.new(user, sp1_ial2_saml_settings.issuer).link_identity(ial: 2)
        user.identities.last.update!(
          verified_attributes: %w[given_name family_name social_security_number address],
        )
        allow(subject).to receive(:attribute_asserter) { asserter }
      end

      it 'calls AttributeAsserter#build' do
        expect(asserter).to receive(:build).at_least(:once).and_call_original

        saml_get_auth(sp1_ial2_saml_settings)
      end

      it 'sets identity ial to 2' do
        saml_get_auth(sp1_ial2_saml_settings)
        expect(user.identities.last.ial).to eq(2)
      end

      it 'does not redirect the user to the IdV URL' do
        saml_get_auth(sp1_ial2_saml_settings)

        expect(response).to_not be_redirect
      end

      it 'contains verified attributes' do
        saml_get_auth(sp1_ial2_saml_settings)

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
        expect(@analytics).to receive(:track_event).
          with(Analytics::SAML_AUTH,
               success: true,
               errors: {},
               nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL,
               authn_context: ['http://idmanagement.gov/ns/assurance/ial/2'],
               service_provider: 'https://rp1.serviceprovider.com/auth/saml/metadata',
               idv: false,
               finish_profile: false)
        expect(@analytics).to receive(:track_event).
          with(Analytics::SP_REDIRECT_INITIATED,
               ial: 2)

        allow(controller).to receive(:identity_needs_verification?).and_return(false)
        saml_get_auth(sp1_ial2_saml_settings)
      end
    end


    context 'with IAL2 and the identity is not already verified' do
      it 'redirects to IdV URL for IAL2 proofer' do
        user = create(:user, :signed_up)
        generate_saml_response(user, sp1_ial2_saml_settings)

        expect(response).to redirect_to idv_path
      end
    end

    context 'with IAL1' do
      it 'does not redirect the user to the IdV URL' do
        user = create(:user, :signed_up)
        generate_saml_response(user, saml_settings)

        expect(response).to_not be_redirect
      end
    end

    context 'authn_context is invalid' do
      it 'renders an error page' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        saml_get_auth(invalid_authn_context_settings)

        expect(controller).to render_template('saml_idp/auth/error')
        expect(response.status).to eq(400)
        expect(response.body).to include(t('errors.messages.unauthorized_authn_context'))

        analytics_hash = {
          success: false,
          errors: { authn_context: [t('errors.messages.unauthorized_authn_context')] },
          nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          authn_context: ['http://idmanagement.gov/ns/assurance/loa/5'],
          service_provider: 'http://localhost:3000',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
      end
    end

    context 'aal_authn_context_enabled is true' do
      let(:user) { create(:user, :signed_up) }
      let(:aal_context_enabled) { 'true' }

      context 'authn_context is missing' do
        let(:auth_settings) { missing_authn_context_saml_settings }

        it 'returns saml response with default AAL in authn context' do
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).
            to eq(Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF)
        end
      end

      context 'authn_context is defined by sp' do
        it 'returns default AAL authn_context when IAL1 is requested' do
          auth_settings = requested_ial1_authn_context_saml_settings
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).
            to eq(Saml::Idp::Constants::DEFAULT_AAL_AUTHN_CONTEXT_CLASSREF)
        end

        it 'returns AAL2 authn_context when AAL2 is requested' do
          auth_settings = requested_aal2_authn_context_saml_settings
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
        end
      end
    end

    context 'aal_authn_context_enabled is false' do
      let(:user) { create(:user, :signed_up) }
      let(:aal_context_enabled) { 'false' }

      context 'authn_context is missing' do
        let(:auth_settings) { missing_authn_context_saml_settings }

        it 'returns saml response with IAL1 in authn context' do
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).to eq(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)
        end
      end

      context 'authn_context is defined by sp' do
        it 'returns IAL1 authn_context when IAL1 is requested' do
          auth_settings = requested_ial1_authn_context_saml_settings
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).to eq(Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF)
        end

        it 'returns AAL2 authn_context when AAL2 is requested' do
          auth_settings = requested_aal2_authn_context_saml_settings
          decoded_saml_response = generate_decoded_saml_response(user, auth_settings)
          authn_context_class_ref = saml_response_authn_context(decoded_saml_response)

          expect(response.status).to eq(200)
          expect(authn_context_class_ref).to eq(Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF)
        end
      end
    end

    context 'service provider is inactive' do
      it 'responds with an error page' do
        user = create(:user, :signed_up)

        generate_saml_response(user, sp2_saml_settings_inactive)

        expect(controller).to redirect_to sp_inactive_error_url
      end
    end

    context 'service provider is invalid' do
      it 'responds with an error page' do
        user = create(:user, :signed_up)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        generate_saml_response(user, invalid_service_provider_settings)

        expect(controller).to render_template('saml_idp/auth/error')
        expect(response.status).to eq(400)
        expect(response.body).to include(t('errors.messages.unauthorized_service_provider'))

        analytics_hash = {
          success: false,
          errors: { service_provider: [t('errors.messages.unauthorized_service_provider')] },
          nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          authn_context: [request_authn_context],
          service_provider: 'invalid_provider',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
      end
    end

    context 'both service provider and authn_context are invalid' do
      it 'responds with an error page' do
        user = create(:user, :signed_up)

        stub_analytics
        allow(@analytics).to receive(:track_event)

        generate_saml_response(user, invalid_service_provider_and_authn_context_settings)

        expect(controller).to render_template('saml_idp/auth/error')
        expect(response.status).to eq(400)
        expect(response.body).to include(t('errors.messages.unauthorized_authn_context'))
        expect(response.body).to include(t('errors.messages.unauthorized_service_provider'))

        analytics_hash = {
          success: false,
          errors: {
            service_provider: [t('errors.messages.unauthorized_service_provider')],
            authn_context: [t('errors.messages.unauthorized_authn_context')],
          },
          nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          authn_context: ['http://idmanagement.gov/ns/assurance/loa/5'],
          service_provider: 'invalid_provider',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
      end
    end

    context 'service provider has multiple certs' do
      let(:service_provider) do
        create(:service_provider,
               cert: nil, # override singular cert
               certs: ['saml_test_sp2', 'saml_test_sp'],
               active: true)
      end

      let(:first_cert_settings) do
        saml_settings.tap do |settings|
          settings.issuer = service_provider.issuer
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

      it 'encrypts the response to the right key' do
        user = create(:user, :signed_up)
        generate_saml_response(user, second_cert_settings)

        expect(response).to_not be_redirect

        expect { xmldoc.saml_response(first_cert_settings) }.to raise_error

        response = xmldoc.saml_response(second_cert_settings)
        expect(response.decrypted_document).to be
      end
    end

    context 'POST to auth correctly stores SP in session' do
      before do
        @user = create(:user, :signed_up)
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
          aal_level_requested: aal_level,
          piv_cac_requested: false,
          ial: 1,
          ial2: false,
          ial2_strict: false,
          ialmax: false,
          request_url: @stored_request_url,
          request_id: sp_request_id,
          requested_attributes: ['email'],
        )
      end
    end

    context 'service provider is valid' do
      before do
        @user = create(:user, :signed_up)
        @saml_request = saml_get_auth(saml_settings)
      end

      it 'stores SP metadata in session' do
        sp_request_id = ServiceProviderRequestProxy.last.uuid

        expect(session[:sp]).to eq(
          issuer: saml_settings.issuer,
          aal_level_requested: aal_level,
          piv_cac_requested: false,
          ial: 1,
          ial2: false,
          ial2_strict: false,
          ialmax: false,
          request_url: @saml_request.request.original_url,
          request_id: sp_request_id,
          requested_attributes: ['email'],
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
          expect(subject.user_session.key?(:verify_shared_attributes)).to eq(true)
        end

        it 'does not redirect after verifying attributes' do
          IdentityLinker.new(@user, saml_settings.issuer).link_identity(
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

    context 'service provider uses email NameID format and is allowed to use email' do
      let(:user) { create(:user, :signed_up) }

      before do
        generate_saml_response(user, email_nameid_saml_settings_for_allowed_issuer)
      end

      # Testing the <saml:Subject> element when the SP is configured to use a
      # NameID format of emailAddress rather than the default persistent UUID.
      context 'Subject' do
        let(:subject) do
          xmldoc.subject_nodeset[0]
        end

        it 'has a saml:Subject element' do
          expect(subject).to_not be_nil
        end

        context 'NameID' do
          let(:name_id) { subject.at('//ds:NameID', ds: Saml::XML::Namespaces::ASSERTION) }

          it 'has a saml:NameID element' do
            expect(name_id).to_not be_nil
          end

          it 'has a format attribute defining the NameID to be email' do
            expect(name_id.attributes['Format'].value).
              to eq(Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL)
          end

          it 'has NameID value of the email address of the user making the AuthN Request' do
            expect(name_id.children.first.to_s).to eq(user.email)
          end
        end
      end
    end

    context 'nameid_format is missing' do
      let(:user) { create(:user, :signed_up) }

      before do
        stub_analytics
        allow(@analytics).to receive(:track_event)
      end

      it 'defaults to persistent' do
        auth_settings = missing_nameid_format_saml_settings
        IdentityLinker.new(user, auth_settings.issuer).link_identity
        user.identities.last.update!(verified_attributes: ['email'])
        generate_saml_response(user, auth_settings)

        expect(response.status).to eq(200)

        analytics_hash = {
          success: true,
          errors: {},
          nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          authn_context: [request_authn_context],
          service_provider: 'http://localhost:3000',
          idv: false,
          finish_profile: false,
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
      end

      it 'defaults to email when added to issuers_with_email_nameid_format' do
        auth_settings = missing_nameid_format_saml_settings_for_allowed_email_issuer
        IdentityLinker.new(user, auth_settings.issuer).link_identity
        user.identities.last.update!(verified_attributes: ['email'])
        generate_saml_response(user, auth_settings)

        expect(response.status).to eq(200)

        analytics_hash = {
          success: true,
          errors: {},
          nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL,
          authn_context: [request_authn_context],
          service_provider: 'https://rp1.serviceprovider.com/auth/saml/metadata',
          idv: false,
          finish_profile: false,
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
      end
    end

    context 'service provider uses email NameID format but is not allowed to use email' do
      it 'returns an error' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        saml_get_auth(email_nameid_saml_settings_for_disallowed_issuer)

        expect(controller).to render_template('saml_idp/auth/error')
        expect(response.status).to eq(400)
        expect(response.body).to include(t('errors.messages.unauthorized_nameid_format'))

        analytics_hash = {
          success: false,
          errors: { nameid_format: [t('errors.messages.unauthorized_nameid_format')] },
          nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_EMAIL,
          authn_context: [request_authn_context],
          service_provider: 'http://localhost:3000',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
      end
    end

    describe 'HEAD /api/saml/auth', type: :request do
      it 'responds with "403 Forbidden"' do
        head '/api/saml/auth2021?SAMLRequest=bang!'

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
      before do
        saml_get_auth(saml_settings)
      end

      it 'redirects the user to the SP landing page with the request_id in the params' do
        sp_request_id = ServiceProviderRequestProxy.last.uuid
        expect(response).to redirect_to new_user_session_path(request_id: sp_request_id)
      end
    end

    context 'after signing in' do
      it 'does not call IdentityLinker' do
        user = create(:user, :signed_up)
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
      let(:user) { create(:user, :signed_up) }

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
        expect(issuer.text).to eq("https://#{AppConfig.env.domain_name}/api/saml")
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
        form_action = response.request.headers.env['secure_headers_request_config'].csp.form_action
        csp_array = ["'self'", 'localhost:3000', 'x-example-app://idp_return']
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
          expect(UUID.validate(assertion['ID'][1..-1])).to eq(true)
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
          element = signature.at('//ds:KeyInfo',
                                 ds: Saml::XML::Namespaces::SIGNATURE)

          expect(element.name).to eq('KeyInfo')
        end

        it 'includes a X509Data element' do
          element = signature.at('//ds:X509Data',
                                 ds: Saml::XML::Namespaces::SIGNATURE)

          expect(element.name).to eq('X509Data')
        end

        it 'includes a X509Certificate element' do
          element = signature.at('//ds:X509Certificate',
                                 ds: Saml::XML::Namespaces::SIGNATURE)

          expect(element.name).to eq('X509Certificate')
        end

        it 'includes the saml cert from the certs folder' do
          element = signature.at('//ds:X509Certificate',
                                 ds: Saml::XML::Namespaces::SIGNATURE)

          crt = AppArtifacts.store.saml_2021_cert
          expect(element.text).to eq(crt.split("\n")[1...-1].join("\n").delete("\n"))
        end

        it 'includes a SignatureValue element' do
          element = signature.at('//ds:Signature/ds:SignatureValue',
                                 ds: Saml::XML::Namespaces::SIGNATURE)

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
            signed_info.at('//ds:SignedInfo/ds:Reference',
                           ds: Saml::XML::Namespaces::SIGNATURE)
          end

          it 'includes a Reference element' do
            expect(reference.name).to eq('Reference')
          end

          it 'includes a URI attribute' do
            expect(UUID.validate(reference['URI'][2..-1])).to eq(true)
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
            subject.at('//ds:SubjectConfirmation',
                       ds: 'urn:oasis:names:tc:SAML:2.0:assertion')
          end

          it 'has a SubjectConfirmation element' do
            expect(subject_confirmation).to_not be_nil
          end

          it 'has a method attribute specifying the bearer method' do
            expect(subject_confirmation.attributes['Method']).to_not be_nil
          end

          context 'SubjectConfirmationData' do
            let(:subject_confirmation_data) do
              subject_confirmation.at('//ds:SubjectConfirmationData',
                                      ds: 'urn:oasis:names:tc:SAML:2.0:assertion')
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

          context 'with AAL authn context enabled' do
            let(:aal_context_enabled) { 'true' }

            it 'has contents set to AAL2' do
              expect(subject.content).to eq Saml::Idp::Constants::AAL2_AUTHN_CONTEXT_CLASSREF
            end
          end

          context 'without AAL authn context enabled' do
            let(:aal_context_enabled) { 'false' }

            it 'has contents set to IAL1' do
              expect(subject.content).to eq Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF
            end
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

    def stub_auth
      allow(controller).to receive(:validate_saml_request_and_authn_context).and_return(true)
      allow(controller).to receive(:user_fully_authenticated?).and_return(true)
      allow(controller).to receive(:link_identity_from_session_data).and_return(true)
      allow(controller).to receive(:current_user).and_return(build(:user))
      allow(controller).to receive(:user_session).and_return({})
    end

    context 'user requires ID verification' do
      it 'tracks the authentication and IdV redirection event' do
        stub_analytics
        stub_auth
        allow(controller).to receive(:remember_device_expired_for_sp?).and_return(false)
        allow(controller).to receive(:identity_needs_verification?).and_return(true)
        allow(controller).to receive(:saml_request).and_return(FakeSamlRequest.new)
        allow(controller).to receive(:saml_request_id).
          and_return(SecureRandom.uuid)
        stub_requested_attributes

        analytics_hash = {
          success: true,
          errors: {},
          nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          authn_context: [Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF],
          service_provider: 'http://localhost:3000',
          idv: true,
          finish_profile: false,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)

        get :auth
      end
    end

    def stub_requested_attributes
      request_parser = instance_double(SamlRequestPresenter)
      service_provider = ServiceProvider.from_issuer('http://localhost:3000')
      service_provider.ial = 2
      service_provider.save
      expect(SamlRequestPresenter).to receive(:new).
        with(request: controller.saml_request, service_provider: service_provider).
        and_return(request_parser)
      allow(request_parser).to receive(:requested_attributes).and_return([:email])
    end

    context 'user is not redirected to IdV' do
      it 'tracks the authentication without IdV redirection event' do
        user = create(:user, :signed_up)

        stub_analytics
        allow(controller).to receive(:identity_needs_verification?).and_return(false)

        analytics_hash = {
          success: true,
          errors: {},
          nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          authn_context: [request_authn_context],
          service_provider: 'http://localhost:3000',
          idv: false,
          finish_profile: false,
        }

        expect(@analytics).to receive(:track_event).with(Analytics::SAML_AUTH, analytics_hash)
        expect(@analytics).to receive(:track_event).
          with(Analytics::SP_REDIRECT_INITIATED,
               ial: 1)

        generate_saml_response(user)

        expect_sp_authentication_cost
      end
    end

    context 'user has not finished verifying profile' do
      it 'tracks the authentication with finish_profile==true' do
        user = create(:user, :signed_up)

        stub_analytics
        allow(controller).to receive(:identity_needs_verification?).and_return(false)
        allow(controller).to receive(:profile_needs_verification?).and_return(true)

        analytics_hash = {
          success: true,
          errors: {},
          nameid_format: Saml::Idp::Constants::NAME_ID_FORMAT_PERSISTENT,
          authn_context: [request_authn_context],
          service_provider: 'http://localhost:3000',
          idv: false,
          finish_profile: true,
        }

        expect(@analytics).to receive(:track_event).with(Analytics::SAML_AUTH, analytics_hash)
        expect(@analytics).to receive(:track_event).
          with(Analytics::SP_REDIRECT_INITIATED,
               ial: 1)

        generate_saml_response(user)

        expect_sp_authentication_cost
      end
    end
  end

  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :disable_caching,
        :validate_saml_request,
        :validate_service_provider_and_authn_context,
        :store_saml_request,
      )
    end
  end

  def expect_sp_authentication_cost
    sp_cost = SpCost.where(issuer: 'http://localhost:3000',
                           cost_type: 'authentication').first
    expect(sp_cost).to be_present
  end
end
