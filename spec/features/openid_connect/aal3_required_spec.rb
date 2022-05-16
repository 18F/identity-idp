require 'rails_helper'

describe 'AAL3 authentication required in an OIDC context' do
  include OidcAuthHelper

  describe 'OpenID Connect requesting AAL3 authentication' do
    context 'user does not have aal3 auth configured' do
      it 'sends user to set up AAL3 auth' do
        user = user_with_2fa

        visit_idp_from_ial1_oidc_sp_requesting_aal3(prompt: 'select_account')
        sign_in_live_with_2fa(user)

        expect(current_url).to eq(authentication_methods_setup_url)
        expect(page).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
        expect(page).to have_xpath("//img[@alt='important alert icon']")
      end
    end

    context 'user has aal3 auth configured' do
      it 'sends user to authenticate with AAL3 auth' do
        sign_in_before_2fa(user_with_aal3_2fa)

        visit_idp_from_ial1_oidc_sp_requesting_aal3(prompt: 'select_account')
        visit login_two_factor_path(otp_delivery_preference: 'sms')
        expect(current_url).to eq(login_two_factor_webauthn_url)
      end

      it 'does not allow an already signed in user to bypass AAL3 auth' do
        sign_in_and_2fa_user(user_with_aal3_2fa)
        visit_idp_from_ial1_oidc_sp_requesting_aal3(prompt: 'select_account')

        expect(current_url).to eq(login_two_factor_webauthn_url)
      end
    end
  end

  describe 'ServiceProvider configured to default to AAL3 authentication' do
    context 'user does not have aal3 auth configured' do
      it 'sends user to set up AAL3 auth' do
        user = user_with_2fa

        visit_idp_from_ial1_oidc_sp_defaulting_to_aal3(prompt: 'select_account')
        sign_in_live_with_2fa(user)

        expect(current_url).to eq(authentication_methods_setup_url)
        expect(page).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
        expect(page).to have_xpath("//img[@alt='important alert icon']")
      end
    end

    context 'user has aal3 auth configured' do
      it 'sends user to authenticate with AAL3 auth' do
        sign_in_before_2fa(user_with_aal3_2fa)
        visit_idp_from_ial1_oidc_sp_defaulting_to_aal3(prompt: 'select_account')
        visit login_two_factor_path(otp_delivery_preference: 'sms')

        expect(current_url).to eq(login_two_factor_webauthn_url)
      end

      it 'does not allow an already signed in user to bypass AAL3 auth' do
        sign_in_and_2fa_user(user_with_aal3_2fa)
        visit_idp_from_ial1_oidc_sp_defaulting_to_aal3(prompt: 'select_account')

        expect(current_url).to eq(login_two_factor_webauthn_url)
      end
    end
  end
end
