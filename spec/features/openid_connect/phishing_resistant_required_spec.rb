require 'rails_helper'

RSpec.describe 'Phishing-resistant authentication required in an OIDC context' do
  include OidcAuthHelper
  include WebAuthnHelper

  shared_examples 'setting up phishing-resistant authenticator in an OIDC context' do
    it 'sends user to set up phishing-resistant auth' do
      sign_in_live_with_2fa(user)

      expect(page).to have_current_path(authentication_methods_setup_path)
      expect(page).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
      expect(page).to have_xpath("//img[@alt='important alert icon']")

      # Validate that user is not allowed to continue without making a selection.
      click_continue
      expect(page).to have_current_path(authentication_methods_setup_path)
      expect(page).to have_content(t('errors.two_factor_auth_setup.must_select_option'))

      # Regression (LG-11110): Ensure the user can reauthenticate with any existing configuration,
      # not limited based on phishing-resistant requirement.
      travel (IdentityConfig.store.reauthn_window + 1).seconds do
        check t('two_factor_authentication.two_factor_choice_options.webauthn')
        click_continue

        expect(page).to have_content(t('two_factor_authentication.login_options.sms'))
        expect(page).to have_content(t('two_factor_authentication.login_options.voice'))

        choose t('two_factor_authentication.login_options.sms')
        click_continue

        fill_in_code_with_last_phone_otp
        click_submit_default

        # LG-11193: Currently the user is redirected back to the MFA setup selection after
        # reauthenticating. This should be improved to remember their original selection.
        expect(page).to have_current_path(authentication_methods_setup_path)
        expect(page).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
        mock_webauthn_setup_challenge
        check t('two_factor_authentication.two_factor_choice_options.webauthn')
        click_continue

        fill_in_nickname_and_click_continue
        mock_press_button_on_hardware_key_on_setup

        expect(page).to have_current_path(sign_up_completed_path)
      end
    end
  end

  describe 'OpenID Connect requesting AAL3 authentication' do
    context 'user does not have phishing-resistant auth configured' do
      let(:user) { create(:user, :fully_registered, :with_phone) }

      before { visit_idp_from_ial1_oidc_sp_requesting_aal3(prompt: 'select_account') }

      it_behaves_like 'setting up phishing-resistant authenticator in an OIDC context'
    end

    context 'user has phishing-resistant auth configured' do
      context 'with piv cac configured' do
        let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

        it 'sends user to authenticate with piv cac' do
          sign_in_before_2fa(user)

          visit_idp_from_ial1_oidc_sp_requesting_aal3(prompt: 'select_account')
          visit login_two_factor_path(otp_delivery_preference: 'sms')
          expect(current_url).to eq(login_two_factor_piv_cac_url)
        end
      end

      context 'with webauthn configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn) }

        it 'sends user to authenticate with webauthn' do
          sign_in_before_2fa(user)

          visit_idp_from_ial1_oidc_sp_requesting_aal3(prompt: 'select_account')
          visit login_two_factor_path(otp_delivery_preference: 'sms')
          expect(current_url).to eq(login_two_factor_webauthn_url)
        end
      end

      context 'with webauthn platform configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

        it 'sends user to authenticate with webauthn platform' do
          sign_in_before_2fa(user)

          visit_idp_from_ial1_oidc_sp_requesting_aal3(prompt: 'select_account')
          visit login_two_factor_path(otp_delivery_preference: 'sms')
          expect(current_url).to eq(login_two_factor_webauthn_url(platform: true))
        end
      end

      it 'does not allow an already signed in user to bypass phishing-resistant auth' do
        sign_in_and_2fa_user(user_with_phishing_resistant_2fa)
        visit_idp_from_ial1_oidc_sp_requesting_aal3(prompt: 'select_account')

        expect(current_url).to eq(login_two_factor_webauthn_url)
      end
    end
  end

  describe 'OpenID Connect requesting phishing-resistant authentication' do
    context 'user does not have phishing-resistant auth configured' do
      let(:user) { create(:user, :fully_registered, :with_phone) }

      before { visit_idp_from_ial1_oidc_sp_requesting_phishing_resistant(prompt: 'select_account') }

      it_behaves_like 'setting up phishing-resistant authenticator in an OIDC context'
    end

    context 'user has phishing-resistant auth configured' do
      context 'with piv cac configured' do
        let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

        it 'sends user to authenticate with piv cac' do
          sign_in_before_2fa(user)

          visit_idp_from_ial1_oidc_sp_requesting_phishing_resistant(prompt: 'select_account')
          visit login_two_factor_path(otp_delivery_preference: 'sms')
          expect(current_url).to eq(login_two_factor_piv_cac_url)
        end
      end

      context 'with webauthn configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn) }

        it 'sends user to authenticate with webauthn' do
          sign_in_before_2fa(user)

          visit_idp_from_ial1_oidc_sp_requesting_phishing_resistant(prompt: 'select_account')
          visit login_two_factor_path(otp_delivery_preference: 'sms')
          expect(current_url).to eq(login_two_factor_webauthn_url)
        end
      end

      context 'with webauthn platform configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

        it 'sends user to authenticate with webauthn platform' do
          sign_in_before_2fa(user)

          visit_idp_from_ial1_oidc_sp_requesting_phishing_resistant(prompt: 'select_account')
          visit login_two_factor_path(otp_delivery_preference: 'sms')
          expect(current_url).to eq(login_two_factor_webauthn_url(platform: true))
        end
      end

      it 'does not allow an already signed in user to bypass phishing-resistant auth' do
        sign_in_and_2fa_user(user_with_phishing_resistant_2fa)
        visit_idp_from_ial1_oidc_sp_requesting_phishing_resistant(prompt: 'select_account')

        expect(current_url).to eq(login_two_factor_webauthn_url)
      end
    end
  end

  describe 'ServiceProvider configured to default to AAL3 authentication' do
    context 'user does not have phishing-resistant auth configured' do
      let(:user) { create(:user, :fully_registered, :with_phone) }

      before { visit_idp_from_ial1_oidc_sp_defaulting_to_aal3(prompt: 'select_account') }

      it_behaves_like 'setting up phishing-resistant authenticator in an OIDC context'
    end

    context 'user has phishing-resistant auth configured' do
      context 'with piv cac configured' do
        let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

        it 'sends user to authenticate with piv cac' do
          sign_in_before_2fa(user)

          visit_idp_from_ial1_oidc_sp_defaulting_to_aal3(prompt: 'select_account')
          visit login_two_factor_path(otp_delivery_preference: 'sms')
          expect(current_url).to eq(login_two_factor_piv_cac_url)
        end
      end

      context 'with webauthn configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn) }

        it 'sends user to authenticate with webauthn' do
          sign_in_before_2fa(user)

          visit_idp_from_ial1_oidc_sp_defaulting_to_aal3(prompt: 'select_account')
          visit login_two_factor_path(otp_delivery_preference: 'sms')
          expect(current_url).to eq(login_two_factor_webauthn_url)
        end
      end

      context 'with webauthn platform configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

        it 'sends user to authenticate with webauthn platform' do
          sign_in_before_2fa(user)

          visit_idp_from_ial1_oidc_sp_defaulting_to_aal3(prompt: 'select_account')
          visit login_two_factor_path(otp_delivery_preference: 'sms')
          expect(current_url).to eq(login_two_factor_webauthn_url(platform: true))
        end
      end

      it 'does not allow an already signed in user to bypass phishing-resistant auth' do
        sign_in_and_2fa_user(user_with_phishing_resistant_2fa)
        visit_idp_from_ial1_oidc_sp_defaulting_to_aal3(prompt: 'select_account')

        expect(current_url).to eq(login_two_factor_webauthn_url)
      end
    end
  end
end
