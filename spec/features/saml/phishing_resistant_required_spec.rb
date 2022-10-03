require 'rails_helper'

describe 'AAL3 authentication required in an SAML context' do
  include SamlAuthHelper

  describe 'SAML ServiceProvider requesting AAL3 authentication' do
    pending 'Pending actual support of multiple auth contexts in SAML'

    context 'user does not have aal3 auth configured' do
      it 'sends user to set up AAL3 auth'
    end

    context 'user has aal3 auth configured' do
      it 'sends user to authenticate with AAL3 auth'
    end
  end

  describe 'SAML ServiceProvider configured to default to phishing-resistant authentication' do
    context 'user does not have phishing-resistant auth configured' do
      it 'sends user to set up phishing-resistant auth' do
        sign_in_and_2fa_user(user_with_2fa)
        visit_saml_authn_request_url(
          overrides: {
            issuer: phishing_resistant_issuer, authn_context: nil
          },
        )

        expect(current_url).to eq(authentication_methods_setup_url)
        expect(page).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
        expect(page).to have_xpath("//img[@alt='important alert icon']")
      end
    end

    context 'user has aal3 auth configured' do
      it 'sends user to authenticate with AAL3 auth' do
        sign_in_before_2fa(user_with_phishing_resistant_2fa)
        visit_saml_authn_request_url(
          overrides: {
            issuer: phishing_resistant_issuer, authn_context: nil
          },
        )
        visit login_two_factor_path(otp_delivery_preference: 'sms')
        expect(current_url).to eq(login_two_factor_webauthn_url)
      end

      it 'does not allow an already signed in user to bypass AAL3 auth' do
        sign_in_and_2fa_user(user_with_phishing_resistant_2fa)
        visit_saml_authn_request_url(
          overrides: {
            issuer: phishing_resistant_issuer, authn_context: nil
          },
        )

        expect(current_url).to eq(login_two_factor_webauthn_url)
      end
    end
  end
end
