require 'rails_helper'

RSpec.describe 'Phishing-resistant authentication required in an SAML context' do
  include SamlAuthHelper
  include WebAuthnHelper

  shared_examples 'setting up phishing-resistant authenticator in an SAML context' do
    it 'sends user to set up phishing-resistant auth' do
      expect(page).to have_current_path(authentication_methods_setup_path)
      expect(page).to have_content(t('two_factor_authentication.two_factor_aal3_choice'))
      expect(page).to have_xpath("//img[@alt='important alert icon']")

      # Validate that user is not allowed to continue without making a selection.
      click_continue
      expect(page).to have_current_path(authentication_methods_setup_path)
      expect(page).to have_content(t('errors.two_factor_auth_setup.must_select_option'))

      # Regression (LG-11110): Ensure the user can reauthenticate with any existing configuration,
      # not limited based on phishing-resistant requirement.
      expire_reauthn_window
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

  describe 'SAML ServiceProvider requesting phishing-resistant authentication' do
    context 'user does not have phishing-resistant auth configured' do
      let(:user) { create(:user, :proofed, :with_phone) }

      before do
        sign_in_and_2fa_user(user)
        visit_saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer,
            authn_context: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
          },
        )
      end

      it_behaves_like 'setting up phishing-resistant authenticator in an SAML context'
    end

    context 'user has phishing-resistant auth configured' do
      context 'with piv cac configured' do
        let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

        it 'sends user to authenticate with piv cac and removes weaker options' do
          sign_in_before_2fa(user)

          visit_saml_authn_request_url(
            overrides: {
              issuer: sp1_issuer,
              authn_context: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            },
          )
          expect(current_url).to eq(login_two_factor_piv_cac_url)
          click_on t('two_factor_authentication.login_options_link_text')
          expect(has_2fa_option?(:piv_cac)).to eq(true)
          expect(has_2fa_option?(:sms)).to eq(false)
        end
      end

      context 'with webauthn configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn) }

        it 'sends user to authenticate with webauthn and removes weaker options' do
          sign_in_before_2fa(user)

          visit_saml_authn_request_url(
            overrides: {
              issuer: sp1_issuer,
              authn_context: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            },
          )
          expect(current_url).to eq(login_two_factor_webauthn_url)
          click_on t('two_factor_authentication.login_options_link_text')
          expect(has_2fa_option?(:webauthn)).to eq(true)
          expect(has_2fa_option?(:sms)).to eq(false)
        end
      end

      context 'with webauthn platform configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

        it 'sends user to authenticate with webauthn platform and removes weaker options' do
          sign_in_before_2fa(user)

          visit_saml_authn_request_url(
            overrides: {
              issuer: sp1_issuer,
              authn_context: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            },
          )
          expect(current_url).to eq(login_two_factor_webauthn_url(platform: true))
          click_on t('two_factor_authentication.login_options_link_text')
          expect(has_2fa_option?(:webauthn_platform)).to eq(true)
          expect(has_2fa_option?(:sms)).to eq(false)
        end
      end

      context 'adding an ineligible method after authenticating with phishing-resistant' do
        before do
          signin_with_piv
          within('.sidenav') { click_on t('account.navigation.add_phone_number') }
          fill_in t('two_factor_authentication.phone_label'), with: '5135550100'
          click_send_one_time_code
          fill_in_code_with_last_phone_otp
          click_submit_default
        end

        it 'does not prompt the user to authenticate again' do
          visit_saml_authn_request_url(
            overrides: {
              authn_context: Saml::Idp::Constants::AAL2_PHISHING_RESISTANT_AUTHN_CONTEXT_CLASSREF,
            },
          )

          expect(page).to have_current_path(sign_up_completed_path)
        end
      end
    end
  end

  describe 'SAML ServiceProvider requesting AAL3 authentication' do
    context 'user does not have phishing-resistant auth configured' do
      let(:user) { create(:user, :proofed, :with_phone) }

      before do
        sign_in_and_2fa_user(user)
        visit_saml_authn_request_url(
          overrides: {
            issuer: sp1_issuer, authn_context: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
          },
        )
      end

      it_behaves_like 'setting up phishing-resistant authenticator in an SAML context'
    end

    context 'user has phishing-resistant auth configured' do
      context 'with piv cac configured' do
        let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

        it 'sends user to authenticate with piv cac and removes weaker options' do
          sign_in_before_2fa(user)

          visit_saml_authn_request_url(
            overrides: {
              issuer: sp1_issuer, authn_context: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
            },
          )
          expect(current_url).to eq(login_two_factor_piv_cac_url)
          click_on t('two_factor_authentication.login_options_link_text')
          expect(has_2fa_option?(:piv_cac)).to eq(true)
          expect(has_2fa_option?(:sms)).to eq(false)
        end
      end

      context 'with webauthn configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn) }

        it 'sends user to authenticate with webauthn and removes weaker options' do
          sign_in_before_2fa(user)

          visit_saml_authn_request_url(
            overrides: {
              issuer: sp1_issuer, authn_context: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
            },
          )
          expect(current_url).to eq(login_two_factor_webauthn_url)
          click_on t('two_factor_authentication.login_options_link_text')
          expect(has_2fa_option?(:webauthn)).to eq(true)
          expect(has_2fa_option?(:sms)).to eq(false)
        end
      end

      context 'with webauthn platform configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

        it 'sends user to authenticate with webauthn platform and removes weaker options' do
          sign_in_before_2fa(user)

          visit_saml_authn_request_url(
            overrides: {
              issuer: sp1_issuer, authn_context: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF
            },
          )
          expect(current_url).to eq(login_two_factor_webauthn_url(platform: true))
          click_on t('two_factor_authentication.login_options_link_text')
          expect(has_2fa_option?(:webauthn_platform)).to eq(true)
          expect(has_2fa_option?(:sms)).to eq(false)
        end
      end

      context 'adding an ineligible method after authenticating with phishing-resistant' do
        before do
          signin_with_piv
          within('.sidenav') { click_on t('account.navigation.add_phone_number') }
          fill_in t('two_factor_authentication.phone_label'), with: '5135550100'
          click_send_one_time_code
          fill_in_code_with_last_phone_otp
          click_submit_default
        end

        it 'does not prompt the user to authenticate again' do
          visit_saml_authn_request_url(
            overrides: {
              authn_context: Saml::Idp::Constants::AAL3_AUTHN_CONTEXT_CLASSREF,
            },
          )

          expect(page).to have_current_path(sign_up_completed_path)
        end
      end
    end
  end

  describe 'SAML ServiceProvider configured to default to AAL3 authentication' do
    context 'user does not have phishing-resistant auth configured' do
      let(:user) { create(:user, :proofed, :with_phone) }

      before do
        sign_in_and_2fa_user(user)
        visit_saml_authn_request_url(
          overrides: {
            issuer: aal3_issuer, authn_context: nil
          },
        )
      end

      it_behaves_like 'setting up phishing-resistant authenticator in an SAML context'
    end

    context 'user has phishing-resistant auth configured' do
      context 'with piv cac configured' do
        let(:user) { create(:user, :fully_registered, :with_piv_or_cac) }

        it 'sends user to authenticate with piv cac and removes weaker options' do
          sign_in_before_2fa(user)

          visit_saml_authn_request_url(
            overrides: {
              issuer: aal3_issuer, authn_context: nil
            },
          )
          expect(current_url).to eq(login_two_factor_piv_cac_url)
          click_on t('two_factor_authentication.login_options_link_text')
          expect(has_2fa_option?(:piv_cac)).to eq(true)
          expect(has_2fa_option?(:sms)).to eq(false)
        end
      end

      context 'with webauthn configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn) }

        it 'sends user to authenticate with webauthn and removes weaker options' do
          sign_in_before_2fa(user)

          visit_saml_authn_request_url(
            overrides: {
              issuer: aal3_issuer, authn_context: nil
            },
          )
          expect(current_url).to eq(login_two_factor_webauthn_url)
          click_on t('two_factor_authentication.login_options_link_text')
          expect(has_2fa_option?(:webauthn)).to eq(true)
          expect(has_2fa_option?(:sms)).to eq(false)
        end
      end

      context 'with webauthn platform configured' do
        let(:user) { create(:user, :fully_registered, :with_webauthn_platform) }

        it 'sends user to authenticate with webauthn platform and removes weaker options' do
          sign_in_before_2fa(user)

          visit_saml_authn_request_url(
            overrides: {
              issuer: aal3_issuer, authn_context: nil
            },
          )
          expect(current_url).to eq(login_two_factor_webauthn_url(platform: true))
          click_on t('two_factor_authentication.login_options_link_text')
          expect(has_2fa_option?(:webauthn_platform)).to eq(true)
          expect(has_2fa_option?(:sms)).to eq(false)
        end
      end

      it 'does not allow an already signed in user to bypass phishing-resistant auth' do
        sign_in_and_2fa_user(user_with_phishing_resistant_2fa)
        visit_saml_authn_request_url(
          overrides: {
            issuer: aal3_issuer, authn_context: nil
          },
        )

        expect(current_url).to eq(login_two_factor_webauthn_url)
      end

      context 'adding an ineligible method after authenticating with phishing-resistant' do
        before do
          signin_with_piv
          within('.sidenav') { click_on t('account.navigation.add_phone_number') }
          fill_in t('two_factor_authentication.phone_label'), with: '5135550100'
          click_send_one_time_code
          fill_in_code_with_last_phone_otp
          click_submit_default
        end

        it 'does not prompt the user to authenticate again' do
          visit_saml_authn_request_url(
            overrides: {
              issuer: aal3_issuer,
              authn_context: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
            },
          )

          expect(page).to have_current_path(sign_up_completed_path)
        end
      end
    end
  end

  def has_2fa_option?(auth_method)
    page.find("label[for='two_factor_options_form_selection_#{auth_method}']")
    true
  rescue Capybara::ElementNotFound
    false
  end
end
