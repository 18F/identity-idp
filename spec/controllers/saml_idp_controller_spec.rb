require 'rails_helper'

describe SamlIdpController do
  include SamlAuthHelper

  render_views

  describe '/api/saml/logout' do
    let(:user) { create(:user, :signed_up) }
    before { sign_in user }

    it 'clears session state' do
      subject.session[:foo] = 'bar'
      expect(subject.session[:foo]).to eq('bar')

      delete :logout
      expect(subject.session[:foo]).to be_nil
    end

    it 'tracks the event when idp-initiated' do
      stub_analytics
      result = { sp_initiated: false, oidc: false, saml_request_valid: false }

      expect(@analytics).to receive(:track_event).with(Analytics::LOGOUT_INITIATED, result)

      delete :logout
    end

    it 'tracks the event when sp-initiated' do
      allow(controller).to receive(:saml_request).and_return(FakeSamlRequest.new)
      stub_analytics
      result = { sp_initiated: true, oidc: false, saml_request_valid: true }

      expect(@analytics).to receive(:track_event).with(Analytics::LOGOUT_INITIATED, result)

      delete :logout, params: { SAMLRequest: 'foo' }
    end

    it 'tracks the event when sp-initiated and the saml request is not valid' do
      stub_analytics
      result = { sp_initiated: true, oidc: false, saml_request_valid: false }

      expect(@analytics).to receive(:track_event).with(Analytics::LOGOUT_INITIATED, result)

      delete :logout, params: { SAMLRequest: 'foo' }
    end
  end

  describe 'POST /api/saml/logout' do
    context 'when there is an invalid SAML packet' do
      let(:user) { create(:user, :signed_up) }

      it 'responds with "400 Bad Request"' do
        sign_in user

        post :logout, params: { SAMLRequest: 'foo' }
        expect(response.status).to eq(400)
      end
    end
    context 'when SAML response is not successful' do
      let(:user) { create(:user, :signed_up) }

      it 'finishes SLO at the IdP' do
        user.identities << Identity.create(
          service_provider: 'foo',
          last_authenticated_at: Time.zone.now
        )
        sign_in user

        post :logout, params: {
          SAMLResponse: 'PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4' \
                        '8c2FtbDJwOkxvZ291dFJlc3BvbnNlIHhtbG5zOnNhbWwycD0idX' \
                        'JuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOnByb3RvY29sIiBEZ' \
                        'XN0aW5hdGlvbj0iaHR0cHM6Ly9teWFjY291bnQudXNjaXMuZGhz' \
                        'Lmdvdi9hcGkvc2FtbC9sb2dvdXQiIElEPSJhMzZkYWloNWNqYmo' \
                        'zMWI5NDYwZGJiajNqZDQ2N2I0IiBJblJlc3BvbnNlVG89Il81Zj' \
                        'dlYjU3MC01YjQ3LTRhMzAtYjUzNi0yY2YyOThhY2NmNmYiIElzc' \
                        '3VlSW5zdGFudD0iMjAxNS0xMi0wMlQxNToyNzo0OS4zNzFaIiBW' \
                        'ZXJzaW9uPSIyLjAiPjxzYW1sMjpJc3N1ZXIgeG1sbnM6c2FtbDI' \
                        '9InVybjpvYXNpczpuYW1lczp0YzpTQU1MOjIuMDphc3NlcnRpb2' \
                        '4iPmV4dGVybmFsYXBwX3ByXzMwYTwvc2FtbDI6SXNzdWVyPjxzY' \
                        'W1sMnA6U3RhdHVzPjxzYW1sMnA6U3RhdHVzQ29kZSBWYWx1ZT0i' \
                        'dXJuOm9hc2lzOm5hbWVzOnRjOlNBTUw6Mi4wOnN0YXR1czpVbmt' \
                        'ub3duUHJpbmNpcGFsIi8+PHNhbWwycDpTdGF0dXNNZXNzYWdlPk' \
                        '5vIHVzZXIgaXMgbG9nZ2VkIGluPC9zYW1sMnA6U3RhdHVzTWVzc' \
                        '2FnZT48L3NhbWwycDpTdGF0dXM+PC9zYW1sMnA6TG9nb3V0UmVz' \
                        'cG9uc2U+',
        }
        expect(response).to redirect_to root_url
      end
    end
  end

  describe '/api/saml/metadata' do
    before do
      get :metadata
    end

    let(:org_name) { '18F' }
    let(:xmldoc) { SamlResponseDoc.new('controller', 'metadata', response) }

    it 'renders XML inline' do
      expect(response.content_type).to eq 'text/xml'
    end

    it 'contains an EntityDescriptor nodeset' do
      expect(xmldoc.metadata_nodeset.length).to eq(1)
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
  end

  describe 'GET /api/saml/auth' do
    let(:xmldoc) { SamlResponseDoc.new('controller', 'response_assertion', response) }

    context 'with LOA3 and the identity is already verified' do
      let(:user) { create(:profile, :active, :verified).user }
      let(:pii) do
        Pii::Attributes.new_from_hash(
          first_name: 'Some',
          last_name: 'One',
          ssn: '666666666',
          zipcode: '12345'
        )
      end
      let(:this_authn_request) do
        raw_req = CGI.unescape loa3_authnrequest.split('SAMLRequest').last
        SamlIdp::Request.from_deflated_request(raw_req)
      end
      let(:asserter) do
        AttributeAsserter.new(
          user: user,
          service_provider: ServiceProvider.from_issuer(loa3_saml_settings.issuer),
          authn_request: this_authn_request,
          decrypted_pii: pii
        )
      end

      before do
        stub_sign_in(user)
        IdentityLinker.new(user, loa3_saml_settings.issuer).link_identity(ial: 3)
        user.identities.last.update!(
          verified_attributes: %w[given_name family_name social_security_number address]
        )
        allow(subject).to receive(:attribute_asserter) { asserter }
      end

      it 'calls AttributeAsserter#build' do
        expect(asserter).to receive(:build).at_least(:once).and_call_original

        saml_get_auth(loa3_saml_settings)
      end

      it 'sets identity loa to 3' do
        saml_get_auth(loa3_saml_settings)
        expect(user.identities.last.ial).to eq(3)
      end

      it 'does not redirect the user to the IdV URL' do
        saml_get_auth(loa3_saml_settings)

        expect(response).to_not be_redirect
      end

      it 'contains verified attributes' do
        saml_get_auth(loa3_saml_settings)

        expect(xmldoc.attribute_node_for('address1')).to be_nil

        %w[first_name last_name ssn zipcode].each do |attr|
          node_value = xmldoc.attribute_value_for(attr)
          expect(node_value).to eq(pii[attr])
        end

        expect(xmldoc.attribute_value_for('verified_at')).to eq(
          user.active_profile.verified_at.iso8601
        )
      end
    end

    context 'with LOA3 and the identity is not already verified' do
      it 'redirects to IdV URL for LOA3 proofer' do
        user = create(:user, :signed_up)
        generate_saml_response(user, loa3_saml_settings)

        expect(response).to redirect_to verify_path
      end
    end

    context 'with LOA1' do
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
          authn_context: 'http://idmanagement.gov/ns/assurance/loa/5',
          service_provider: 'http://localhost:3000',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
      end
    end

    context 'authn_context is missing' do
      it 'defaults to LOA1' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        user = create(:user, :signed_up)
        auth_settings = missing_authn_context_saml_settings
        IdentityLinker.new(user, auth_settings.issuer).link_identity
        user.identities.last.update!(verified_attributes: ['email'])
        generate_saml_response(user, auth_settings)

        expect(response.status).to eq(200)

        analytics_hash = {
          success: true,
          errors: {},
          authn_context: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
          service_provider: 'http://localhost:3000',
          idv: false,
          finish_profile: false,
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
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
          authn_context: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
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
          authn_context: 'http://idmanagement.gov/ns/assurance/loa/5',
          service_provider: 'invalid_provider',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
      end
    end

    context 'service provider is valid' do
      before do
        @user = create(:user, :signed_up)
        @saml_request = saml_get_auth(saml_settings)
      end

      it 'stores SP metadata in session' do
        sp_request_id = ServiceProviderRequest.last.uuid

        expect(session[:sp]).to eq(
          issuer: saml_settings.issuer,
          loa3: false,
          request_url: @saml_request.request.original_url,
          request_id: sp_request_id,
          requested_attributes: ['email']
        )
      end

      context 'after successful assertion of loa1' do
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

        it 'does links the user to the service provider' do
          expect(user_identity).to_not be_nil
        end

        it 'sets verified attributes on the identity to nothing' do
          expect(user_identity.verified_attributes).to eq([])
        end

        it 'sets user identity loa value to 1 after verifying attributes' do
          saml_get_auth(saml_settings)
          expect(user_identity.ial).to eq(1)
        end

        it 'redirects to verify attributes' do
          expect(response).to redirect_to sign_up_completed_url
          expect(subject.user_session.key?(:verify_shared_attributes)).to eq(true)
        end

        it 'does not redirect after verifying attributes' do
          IdentityLinker.new(@user, saml_settings.issuer).link_identity(
            verified_attributes: ['email']
          )
          saml_get_auth(saml_settings)

          expect(response).to_not redirect_to sign_up_completed_url
        end

        it 'redirects if verified attributes dont match requested attributes' do
          saml_get_auth(saml_settings)

          user_identity.update!(verified_attributes: nil)
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
        let(:subject) { xmldoc.subject_nodeset[0] }

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
              to eq('urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress')
          end

          it 'has NameID value of the email address of the user making the AuthN Request' do
            expect(name_id.children.first.to_s).to eq(user.email)
          end
        end
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
          authn_context: 'http://idmanagement.gov/ns/assurance/loa/1',
          service_provider: 'http://localhost:3000',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::SAML_AUTH, analytics_hash)
      end
    end

    describe 'HEAD /api/saml/auth', type: :request do
      it 'responds with "403 Forbidden"' do
        head '/api/saml/auth?SAMLRequest=bang!'

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
        sp_request_id = ServiceProviderRequest.last.uuid
        expect(response).to redirect_to sign_up_start_path(request_id: sp_request_id)
      end
    end

    context 'after signing in' do
      it 'calls IdentityLinker' do
        user = create(:user, :signed_up)
        linker = instance_double(IdentityLinker)

        expect(IdentityLinker).to receive(:new).once.
          with(user, saml_settings.issuer).and_return(linker)
        expect(linker).to receive(:link_identity)

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
        expect(issuer.text).to eq("https://#{Figaro.env.domain_name}/api/saml")
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

        it 'includes saml.crt from the certs folder' do
          element = signature.at('//ds:X509Certificate',
                                 ds: Saml::XML::Namespaces::SIGNATURE)

          crt = File.read(Rails.root.join('certs', 'saml.crt'))
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
            ds: Saml::XML::Namespaces::ASSERTION
          )
        end

        it 'has a saml:AuthnContext element' do
          expect(subject).to_not be_nil
        end

        context 'AuthnContextClassRef' do
          let(:subject) do
            xmldoc.saml_document.at(
              '//ds:AuthnStatement/ds:AuthnContext/ds:AuthnContextClassRef',
              ds: Saml::XML::Namespaces::ASSERTION
            )
          end

          it 'has a saml:AuthnContextClassRef element' do
            expect(subject).to_not be_nil
          end

          it 'has contents set to LOA1' do
            expect(subject.content).to eq Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF
          end
        end
      end

      # a <saml:AttributeStatement> element, which asserts a multi-valued
      # attribute associated with the authenticated principal
      context 'saml:AttributeStatement' do
        it 'includes the saml:AttributeStatement element' do
          attribute_statement = xmldoc.saml_document.at(
            '//*/saml:AttributeStatement',
            saml: Saml::XML::Namespaces::ASSERTION
          )

          expect(attribute_statement.class).to eq(Nokogiri::XML::Element)
          expect(attribute_statement.name).to eq('AttributeStatement')
        end

        it 'includes the email Attribute element' do
          email = xmldoc.attribute_node_for('email')

          expect(email.name).to eq('Attribute')
          expect(email['Name']).to eq('email')
          expect(email['NameFormat']).to eq(Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS)
          expect(email['FriendlyName']).to eq('email')
        end

        it 'includes the uuid Attribute element' do
          uuid = xmldoc.attribute_node_for('uuid')

          expect(uuid.name).to eq('Attribute')
          expect(uuid['Name']).to eq('uuid')
          expect(uuid['NameFormat']).to eq(Saml::XML::Namespaces::Formats::NameId::PERSISTENT)
          expect(uuid['FriendlyName']).to eq('uuid')
        end

        it 'does not include the phone Attribute element when authn_context is LOA1' do
          phone = xmldoc.phone_number

          expect(phone).to be_nil
        end
      end
    end

    def stub_auth
      allow(controller).to receive(:validate_saml_request_and_authn_context).and_return(true)
      allow(controller).to receive(:user_fully_authenticated?).and_return(true)
      allow(controller).to receive(:link_identity_from_session_data).and_return(true)
    end

    context 'user requires ID verification' do
      it 'tracks the authentication and IdV redirection event' do
        stub_analytics
        stub_auth
        allow(controller).to receive(:identity_needs_verification?).and_return(true)
        allow(controller).to receive(:saml_request).and_return(FakeSamlRequest.new)
        allow(controller).to receive(:saml_request_id).
          and_return(SecureRandom.uuid)
        stub_requested_attributes

        analytics_hash = {
          success: true,
          errors: {},
          authn_context: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
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
          authn_context: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
          service_provider: 'http://localhost:3000',
          idv: false,
          finish_profile: false,
        }

        expect(@analytics).to receive(:track_event).with(Analytics::SAML_AUTH, analytics_hash)

        generate_saml_response(user)
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
          authn_context: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
          service_provider: 'http://localhost:3000',
          idv: false,
          finish_profile: true,
        }

        expect(@analytics).to receive(:track_event).with(Analytics::SAML_AUTH, analytics_hash)

        generate_saml_response(user)
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
        :add_sp_metadata_to_session
      )
    end
  end
end
