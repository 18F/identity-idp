require 'rails_helper'

describe SamlIdpController do
  include SamlResponseHelper
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
  end

  describe 'POST /api/saml/logout' do
    context 'when SAML response is not successful' do
      let(:user) { create(:user, :signed_up) }

      it 'finishes SLO at the IdP' do
        user.identities << Identity.create(
          service_provider: 'foo',
          last_authenticated_at: Time.current
        )
        sign_in user

        post :logout, SAMLResponse: 'PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4' \
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
                                        'cG9uc2U+'
        expect(response).to redirect_to root_url
      end
    end
  end

  describe '/api/saml/metadata' do
    before do
      get :metadata
    end

    let(:org_name) { '18F' }
    let(:xmldoc) { SamlResponseHelper::XmlDoc.new('controller', 'metadata', response) }

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
    context 'with LOA3 but the identity is already verified' do
      before do
        allow_any_instance_of(ServiceProvider).to receive(:attribute_bundle).and_return(
          %w(first_name last_name ssn zipcode)
        )
      end

      it 'calls AttributeAsserter#build' do
        settings = loa3_saml_settings
        user = create(:user, :signed_up)
        create(:profile, :active, :verified, user: user)

        raw_req = URI.decode loa3_authnrequest.split('SAMLRequest').last
        authn_request = SamlIdp::Request.from_deflated_request(raw_req)
        asserter = AttributeAsserter.new(user, ServiceProvider.new(settings.issuer), authn_request)

        expect(AttributeAsserter).to receive(:new).and_return(asserter)
        expect(asserter).to receive(:build).at_least(:once)

        generate_saml_response(user, settings)
      end

      it 'does not redirect the user to the IdV URL' do
        user = create(:user, :signed_up)
        _profile = create(:profile, :active, :verified, user: user)
        generate_saml_response(user, loa3_saml_settings)

        expect(response).to_not be_redirect
      end

      it 'contains verified attributes' do
        user = create(:user, :signed_up)
        user.profiles.create(
          verified_at: Time.current,
          active: true,
          activated_at: Time.current,
          first_name: 'Some',
          last_name: 'One',
          ssn: '666666666',
          zipcode: '12345'
        )
        generate_saml_response(user, loa3_saml_settings)

        xpath = '//ds:Attribute[@Name="address1"]'
        expect(decrypted_saml_response.at(xpath, ds: Saml::XML::Namespaces::ASSERTION)).to be_nil

        %w(first_name last_name ssn zipcode).each do |attr|
          xpath = %(//ds:Attribute[@Name="#{attr}"])
          node = decrypted_saml_response.at(xpath, ds: Saml::XML::Namespaces::ASSERTION)
          node_value = node.children.children.to_s
          expect(node_value).to eq(user.active_profile[attr.to_sym])
        end
      end
    end

    context 'with LOA3 and the identity is not already verified' do
      it 'redirects to IdV URL for LOA3 proofer' do
        user = create(:user, :signed_up)
        generate_saml_response(user, loa3_saml_settings)

        expect(response).to redirect_to idv_url
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
      it 'renders nothing with a 400 error' do
        saml_get_auth(invalid_authn_context_settings)

        expect(response.status).to eq(400)
        expect(response.body).to be_empty
      end
    end

    context 'authn_context is missing' do
      it 'renders nothing with a 400 error' do
        saml_get_auth(missing_authn_context_saml_settings)

        expect(response.status).to eq(400)
        expect(response.body).to be_empty
      end
    end

    describe 'HEAD /api/saml/auth', type: :request do
      it 'responds with "400 Forbidden" with unknown bindings' do
        head '/api/saml/auth?SAMLRequest=bang!'

        expect(response.status).to eq(403)
      end
    end

    context 'with invalid requests' do
      it 'responds with "403 Forbidden" to GET requests without SAML request params' do
        get :auth
        expect(response.status).to eq(403)
      end

      it 'responds with a 403 error' do
        get(:auth, SAMLRequest: 'bang!')

        expect(response.status).to eq(403)
      end
    end

    context 'when user is not logged in' do
      before do
        saml_get_auth(saml_settings)
      end

      it 'redirects the user to the home page (sign in)' do
        expect(response).to redirect_to root_url
      end
    end

    context 'after signing in' do
      before do
        user = create(:user, :signed_up)
        generate_saml_response(user)
      end

      it 'stores the SAML Request original_url in the session' do
        expect(session[:saml_request_url]).to eq(request.original_url)
      end

      it 'calls IdentityLinker' do
        user = create(:user, :signed_up)

        linker = instance_double(IdentityLinker)

        expect(IdentityLinker).to receive(:new).
          with(
            controller.current_user,
            saml_settings.issuer,
            'http://idmanagement.gov/ns/assurance/loa/1'
          ).and_return(linker)

        expect(linker).to receive(:link_identity)

        generate_saml_response(user)
      end
    end

    context 'SAML Response' do
      let(:xmldoc) { SamlResponseHelper::XmlDoc.new('controller', 'auth', response) }

      before do
        user = create(:user, :signed_up)
        generate_saml_response(user, saml_settings)
      end

      it 'returns a valid xml document' do
        expect(decrypted_saml_response.validate).to be(nil)
      end

      # a <saml:Issuer> element, which contains the unique identifier of the identity provider
      # NOTE JJG: I'm not sure where this is set or why we use this
      it 'includes an Issuer element inherited from the base URL' do
        expect(decrypted_saml_response.root.children.include?(issuer)).to be(true)
        expect(issuer.name).to eq('Issuer')
        expect(issuer.namespace.href).to eq(Saml::XML::Namespaces::ASSERTION)
        expect(issuer.text).to eq("https://#{Figaro.env.domain_name}/api/saml")
      end

      it 'includes a Status element with a StatusCode child element' do
        # https://msdn.microsoft.com/en-us/library/hh269633.aspx
        expect(decrypted_saml_response.root.children.include?(status)).to be(true)
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

      # http://en.wikipedia.org/wiki/SAML_2.0#SAML_2.0_Assertions
      context 'Assertion' do
        let(:assertion) do
          decrypted_saml_response.at('//ds:Assertion',
                                     ds: Saml::XML::Namespaces::ASSERTION)
        end

        it 'includes the xmlns:saml attribute in the element' do
          # JJG NOTE: should this be xmlns:saml? See example block at:
          # http://en.wikipedia.org/wiki/SAML_2.0#SAML_2.0_Assertions
          # expect(assertion.namespaces['xmlns:saml'])
          #   .to eq('urn:oasis:names:tc:SAML:2.0:assertion')
          expect(assertion.namespace.href).to eq(Saml::XML::Namespaces::ASSERTION)
        end

        it 'includes an ID attribute with a valid UUID' do
          expect(UUID.validate(assertion['ID'][1..-1])).to eq(true)
          expect(assertion['ID']).to eq "_#{User.last.last_identity.session_uuid}"
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

      # a <saml:Issuer> element, which contains the unique identifier of the
      # identity provider
      context 'Issuer' do
        let(:assertion_issuer) do
          decrypted_saml_response.at('//ds:Assertion/ds:Issuer',
                                     ds: Saml::XML::Namespaces::ASSERTION)
        end

        it 'includes an Issuer element and uses the base API url for a unique identifier' do
          expect(assertion_issuer.name).to eq('Issuer')
          expect(assertion_issuer.text).to eq("https://#{Figaro.env.domain_name}/api/saml")
        end
      end

      # a <ds:Signature> element, which contains an integrity-preserving
      # digital signature (not shown) over the <saml:Assertion> element
      context 'ds:Signature' do
        let(:signature) do
          decrypted_saml_response.at('//ds:Signature',
                                     ds: Saml::XML::Namespaces::SIGNATURE)
        end

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

          crt = File.read("#{Rails.root}/certs/saml.crt")
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
        let(:signed_info) do
          decrypted_saml_response.at(
            '//ds:SignedInfo',
            ds: Saml::XML::Namespaces::SIGNATURE
          )
        end

        it 'includes a SignedInfo element' do
          expect(signed_info.name).to eq('SignedInfo')
        end

        it 'includes a CanonicalizationMethod element' do
          element = signed_info.at('//ds:CanonicalizationMethod',
                                   ds: Saml::XML::Namespaces::SIGNATURE)

          expect(element.name).to eq('CanonicalizationMethod')
          expect(element['Algorithm']).to eq('http://www.w3.org/2001/10/xml-exc-c14n#')
        end

        it 'includes a SignatureMethod element specifying rsa-sha256' do
          element = signed_info.at('//ds:SignedInfo/ds:SignatureMethod',
                                   ds: Saml::XML::Namespaces::SIGNATURE)

          expect(element.name).to eq('SignatureMethod')
          expect(element['Algorithm']).to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')
        end

        it 'includes a DigestMethod element' do
          element = signed_info.at('//ds:DigestMethod',
                                   ds: Saml::XML::Namespaces::SIGNATURE)

          expect(element.name).to eq('DigestMethod')
          expect(element['Algorithm']).to eq('http://www.w3.org/2001/04/xmlenc#sha256')
        end

        it 'includes a DigestValue element' do
          element = signed_info.at('//ds:DigestValue',
                                   ds: Saml::XML::Namespaces::SIGNATURE)

          expect(element.name).to eq('DigestValue')

          # Not sure how to check this, I think it may be created in the
          # AuthN req
          # expect(element.text).to eq('MN0TRdEU/ks2o5dot/Rl6stsOxRhwLyZvAD7Qv/QlJU=')
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
        let(:transforms) do
          decrypted_saml_response.at('//ds:Reference/ds:Transforms',
                                     ds: Saml::XML::Namespaces::SIGNATURE)
        end

        it 'includes a Transforms element specifying multiple transformation algorithms' do
          expect(transforms.name).to eq('Transforms')
        end

        it 'includes a Transform specifying the Schema for XML Signatures' do
          algorithm = 'http://www.w3.org/2000/09/xmldsig#enveloped-signature'

          expect(transforms.children.include?(transform(algorithm))).to be(true)
          expect(transform(algorithm)['Algorithm']).to eq(algorithm)
        end

        it 'includes a Transform specifying the Canonical XML serialization' do
          algorithm = 'http://www.w3.org/2001/10/xml-exc-c14n#'

          expect(transforms.children.include?(transform(algorithm))).to be(true)
          expect(transform(algorithm)['Algorithm']).to eq(algorithm)
        end
      end

      # a <saml:Subject> element, which identifies the authenticated
      # principal (but in this case the identity of the principal is
      # hidden behind an opaque transient identifier, for reasons of privacy)
      context 'Subject' do
        let(:subject) do
          decrypted_saml_response.at('//ds:Subject',
                                     ds: 'urn:oasis:names:tc:SAML:2.0:assertion')
        end

        it 'has a saml:Subject element' do
          expect(subject).to_not be_nil
        end

        context 'NameID' do
          let(:name_id) do
            subject.at('//ds:NameID',
                       ds: 'urn:oasis:names:tc:SAML:2.0:assertion')
          end

          it 'has a saml:NameID element' do
            expect(name_id).to_not be_nil
          end

          it 'has a format attribute specifying the email format' do
            expect(name_id.attributes['Format'].value).
              to eq('urn:oasis:names:tc:SAML:2.0:nameid-format:persistent')
          end

          it 'has the UUID of the user making the AuthN Request' do
            expect(name_id.children.first.to_s).to eq(User.last.uuid)
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
        it 'has a saml:Conditions element'

        it 'has a NotBefore attribute'

        it 'has a NotOnOrAfter attribute'
      end

      # a <saml:AuthnStatement> element, which describes the act of
      # authentication at the identity provider
      context 'AuthnStatement' do
        it 'has a saml:AuthnStatement element'

        it 'has an AuthnInstant attribute'

        it 'has a SessionIndex attribute'
      end

      context 'AuthnContext' do
        it 'has a saml:AuthnContext element'

        context 'AuthnContextClassRef' do
          it 'has a saml:AuthnContextClassRef element'

          it 'has contents set to the loa of the ial?'
        end
      end

      # a <saml:AttributeStatement> element, which asserts a multi-valued
      # attribute associated with the authenticated principal
      context 'saml:AttributeStatement' do
        it 'includes the saml:AttributeStatement element' do
          attribute_statement = decrypted_saml_response.at(
            '//*/saml:AttributeStatement',
            saml: Saml::XML::Namespaces::ASSERTION
          )

          expect(attribute_statement.class).to eq(Nokogiri::XML::Element)
          expect(attribute_statement.name).to eq('AttributeStatement')
        end

        it 'includes the email Attribute element' do
          xpath = '//ds:Attribute[@Name="email"]'
          email = decrypted_saml_response.at(xpath, ds: Saml::XML::Namespaces::ASSERTION)

          expect(email.name).to eq('Attribute')
          expect(email['Name']).to eq('email')
          expect(email['NameFormat']).to eq(Saml::XML::Namespaces::Formats::NameId::EMAIL_ADDRESS)
          expect(email['FriendlyName']).to eq('email')
        end

        it 'includes the uuid Attribute element' do
          xpath = '//ds:Attribute[@Name="uuid"]'
          uuid = decrypted_saml_response.at(xpath, ds: Saml::XML::Namespaces::ASSERTION)

          expect(uuid.name).to eq('Attribute')
          expect(uuid['Name']).to eq('uuid')
          expect(uuid['NameFormat']).to eq(Saml::XML::Namespaces::Formats::NameId::PERSISTENT)
          expect(uuid['FriendlyName']).to eq('uuid')
        end

        it 'includes the mobile Attribute element' do
          xpath = '//ds:Attribute[@Name="mobile"]'
          mobile = decrypted_saml_response.at(xpath, ds: Saml::XML::Namespaces::ASSERTION)

          expect(mobile.name).to eq('Attribute')
          expect(mobile['Name']).to eq('mobile')
          expect(mobile['NameFormat']).to eq(Saml::XML::Namespaces::Formats::Attr::URI)
          expect(mobile['FriendlyName']).to eq('mobile')
        end
      end
    end
  end

  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :disable_caching,
        [:apply_secure_headers_override, only: [:auth, :logout]],
        [:validate_saml_request, only: :auth],
        [:verify_authn_context, only: :auth],
        [:store_saml_request_in_session, only: :auth],
        [:confirm_two_factor_authenticated, only: :auth],
        [:validate_saml_logout_param, only: :logout]
      )
    end
  end
end
