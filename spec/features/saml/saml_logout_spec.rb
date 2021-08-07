require 'rails_helper'

feature 'SAML logout' do
  include SamlAuthHelper

  let(:user) { create(:user, :signed_up) }

  context 'with a SAML request' do
    context 'when logging out from the SP' do
      it 'contains all redirect_uris in CSP when user is logged out of the IDP' do
        sign_in_and_2fa_user(user)
        visit_saml_authn_request_url(
          saml_overrides: {
            issuer: 'saml_sp_ial2',
          },
        )
        click_continue

        # Sign out of the IDP
        visit account_path
        first(:link, t('links.sign_out')).click
        expect(current_path).to eq root_path

        # SAML logout request
        visit_saml_logout_request_url(
          saml_overrides: {
            issuer: 'saml_sp_ial2',
          },
        )

        # contains all redirect_uris in content security policy
        expect(page.response_headers['Content-Security-Policy']).to include(
          'form-action \'self\' example.com example.com/ example.com/auth/result '\
          'example.com/logout',
        )
      end

      it 'contains all redirect_uris in CSP when user is logged in to the IDP' do
        sign_in_and_2fa_user(user)
        visit_saml_authn_request_url(
          saml_overrides: {
            issuer: 'saml_sp_ial2',
          },
        )
        click_continue

        # SAML logout request
        visit_saml_logout_request_url(
          saml_overrides: {
            issuer: 'saml_sp_ial2',
          },
        )

        # contains all redirect_uris in content security policy
        expect(page.response_headers['Content-Security-Policy']).to include(
          'form-action \'self\' example.com example.com/ example.com/auth/result '\
          'example.com/logout',
        )
      end
    end

    context 'the SP implements SLO' do
      it 'logs the user out and redirects to the SP' do
        sign_in_and_2fa_user(user)
        visit_saml_authn_request_url
        click_continue

        visit_saml_logout_request_url

        xmldoc = SamlResponseDoc.new('feature', 'logout_assertion')

        # It should contain a SAMLResponse
        expect(page.find('#SAMLResponse', visible: false)).to be_truthy

        # It should disable caching
        expect(page.response_headers['Pragma']).to eq 'no-cache'

        # It should contain an issuer nodeset
        expect(xmldoc.issuer_nodeset.length).to eq(1)
        expect(xmldoc.issuer_nodeset[0].content).to eq(
          "https://#{IdentityConfig.store.domain_name}/api/saml",
        )

        # It should not contain a SHA256 signature nodeset
        expect(xmldoc.signature_nodeset.length).to eq(0)

        # The user should be signed out
        visit account_path
        expect(current_path).to eq root_path
      end
    end

    context 'the user is not signed in' do
      it 'redirects to the SP' do
        visit_saml_logout_request_url(
          saml_overrides: {
            issuer: 'saml_sp_ial2',
            name_identifier_value: 'asdf-1234',
          },
        )

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

        visit_saml_logout_request_url(
          saml_overrides: {
            issuer: 'invalid_provider',
            name_identifier_value: 'asdf-1234',
          },
          saml_security_overrides: {
            logout_requests_signed: false,
          },
        )

        expect(current_path).to eq(api_saml_logout2021_path)
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

      visit api_saml_logout2021_path

      expect(page).to have_content(t('devise.sessions.signed_out'))
      expect(page).to have_current_path(root_path)

      # The user should be signed out
      visit account_path
      expect(page).to have_current_path(root_path)
    end
  end
end
