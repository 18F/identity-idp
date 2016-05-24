require 'rails_helper'

describe SamlIdpController do
  include SamlResponseHelper
  include SamlAuthHelper

  render_views

  describe '/api/saml/logout' do
    it 'calls UserOtpSender#reset_otp_state' do
      user = create(:user, :signed_up)
      sign_in user

      otp_sender = instance_double(UserOtpSender)
      allow(UserOtpSender).to receive(:new).with(user).and_return(otp_sender)

      expect(otp_sender).to receive(:reset_otp_state)

      delete :logout
    end
  end

  describe '/api/saml/metadata' do
    before do
      begin
        get :metadata
      rescue XMLSec::SigningError
        skip 'Broken on OSX. Use Vagrant to test.'
      end
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
      it 'does not redirect the user to the IdV URL' do
        user = create(:user, :signed_up)
        generate_saml_response(user, loa3_saml_settings)

        user.last_identity.update(ial: 2)

        generate_saml_response(user, loa3_saml_settings)

        expect(response).to_not be_redirect
      end
    end

    context 'with LOA3 and the identity is not already verified' do
      it 'redirects to IdV URL for LOA3 proofer' do
        user = create(:user, :signed_up)
        generate_saml_response(user, loa3_saml_settings)

        expect(response).to redirect_to 'https://loa3.example.com'
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
  end
end
