require 'rails_helper'

feature 'SAML logout' do
  include SamlAuthHelper

  let(:user) { create(:user, :signed_up) }
  let(:sp_saml_settings) { sp1_saml_settings }
  let(:service_provider) { ServiceProvider.from_issuer(sp_saml_settings.issuer) }

  context 'with a SAML request' do
    context 'the SP implements SLO' do
      it 'logs the user out and redirects to the SP' do
        sign_in_and_2fa_user(user)
        visit auth_request.create(sp_saml_settings)
        click_continue

        service_provider = ServiceProvider.from_issuer(sp_saml_settings.issuer)
        settings = sp_saml_settings.dup
        settings.name_identifier_value = user.decorate.active_identity_for(service_provider).uuid

        request = OneLogin::RubySaml::Logoutrequest.new
        visit request.create(settings)

        xmldoc = SamlResponseDoc.new('feature', 'logout_assertion')

        # It should contain a SAMLResponse
        expect(page.find('#SAMLResponse', visible: false)).to be_truthy

        # It should disable caching
        expect(page.response_headers['Pragma']).to eq 'no-cache'

        # It should contain an issuer nodeset
        expect(xmldoc.issuer_nodeset.length).to eq(1)
        expect(xmldoc.issuer_nodeset[0].content).to eq "https://#{Figaro.env.domain_name}/api/saml"

        # It should contain a SHA256 signature nodeset
        expect(xmldoc.signature_nodeset.length).to eq(1)
        expect(xmldoc.signature_method_nodeset[0].attr('Algorithm')).
          to eq('http://www.w3.org/2001/04/xmldsig-more#rsa-sha256')

        # It should contain a SHA256 digest method nodeset
        expect(xmldoc.digest_method_nodeset.length).to eq(1)
        expect(xmldoc.digest_method_nodeset[0].attr('Algorithm')).
          to eq('http://www.w3.org/2001/04/xmlenc#sha256')

        # The user should be signed out
        visit account_path
        expect(current_path).to eq root_path
      end
    end

    context 'the user is not signed in' do
      it 'redirects to the SP' do
        settings = sp_saml_settings.dup
        settings.name_identifier_value = 'asdf-1234'

        request = OneLogin::RubySaml::Logoutrequest.new
        visit request.create(settings)

        # It should contain a SAMLResponse
        expect(page.find('#SAMLResponse', visible: false)).to be_truthy

        # The user should be signed out
        visit account_path
        expect(current_path).to eq root_path
      end
    end

    context 'the saml request is invalid' do
      it 'renders an error' do
        sign_in_and_2fa_user(user)

        settings = invalid_service_provider_settings.dup
        settings.name_identifier_value = 'asdf-1234'
        settings.security[:logout_requests_signed] = false

        request = OneLogin::RubySaml::Logoutrequest.new
        visit request.create(settings)

        expect(current_path).to eq(api_saml_logout2019_path)
        expect(page.driver.status_code).to eq(400)

        # The user should be signed in
        visit account_path
        expect(page).to have_current_path(account_path)
      end
    end
  end

  context 'without a SAML request' do
    it 'logs the user out and redirects to the sign in page' do
      sign_in_and_2fa_user(user)

      visit api_saml_logout2019_path

      expect(page).to have_content(t('devise.sessions.signed_out'))
      expect(page).to have_current_path(root_path)

      # The user should be signed out
      visit account_path
      expect(page).to have_current_path(root_path)
    end
  end
end
