require 'rails_helper'

RSpec.feature 'OIDC requests using VTR', allowed_extra_analytics: [:*] do
  include OidcAuthHelper
  include IdvHelper
  include WebAuthnHelper

  before do
    allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).
      and_return(true)
  end

  scenario 'sign in with VTR request for authentication', :js do
    user = create(:user, :fully_registered)

    visit_idp_from_oidc_sp_with_vtr(vtr: 'C1')

    expect(page).to have_content(t('headings.sign_in_existing_users'))

    sign_in_live_with_2fa(user)

    expect(page).to have_content(
      t('account.index.continue_to_service_provider', service_provider: 'Test SP'),
    )

    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
  end

  scenario 'sign in with VTR request for AAL2 disables remember device', :js do
    user = create(:user, :fully_registered)

    # Sign in and remember device
    sign_in_user(user)
    check t('forms.messages.remember_device')
    fill_in_code_with_last_phone_otp
    click_submit_default
    first(:button, t('links.sign_out')).click

    visit_idp_from_oidc_sp_with_vtr(vtr: 'C1.C2')
    sign_in_user(user)

    # MFA is required despite remember device
    expect(page).to have_current_path(login_two_factor_path(otp_delivery_preference: :sms))
    fill_in_code_with_last_phone_otp
    click_submit_default

    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
  end

  scenario 'sign in with VTR request for phishing-resistance requires phishing-resistanc auth', :js do
    mock_webauthn_setup_challenge
    user = create(:user, :fully_registered)

    visit_idp_from_oidc_sp_with_vtr(vtr: 'C1.Ca')
    sign_in_live_with_2fa(user)

    # More secure MFA is required
    expect(page).to have_current_path(authentication_methods_setup_path)
    expect(page).to have_content(t('two_factor_authentication.two_factor_aal3_choice_intro'))

    # User must setup phishing-resistant auth
    select_2fa_option('webauthn', visible: :all)
    fill_in_nickname_and_click_continue
    mock_press_button_on_hardware_key_on_setup

    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
  end

  xscenario 'sign in with VTR request for HSDP12 auth requires PIV/CAC setup', :js do
    allow(Identity::Hostdata).to receive(:env).and_return('test')
    allow(Identity::Hostdata).to receive(:domain).and_return('example.com')

    stub_piv_cac_service

    user = create(:user, :fully_registered)

    visit_idp_from_oidc_sp_with_vtr(vtr: 'C1.Cb')
    # visit_saml_authn_request_url(
    #   overrides: {
    #     authn_context: 'C1.Cb',
    #   },
    # )

    sign_in_live_with_2fa(user)

    # More secure MFA is required
    expect(page).to have_current_path(authentication_methods_setup_path)
    expect(page).to have_content(t('two_factor_authentication.two_factor_hspd12_choice_intro'))

    # User must setup PIV/CAC before continuing
    visit setup_piv_cac_path
    nonce = piv_cac_nonce_from_form_action
    visit_piv_cac_service(
      setup_piv_cac_url,
      nonce: nonce,
      uuid: SecureRandom.uuid,
      subject: 'SomeIgnoredSubject',
    )

    binding.pry

    click_agree_and_continue

    expect(current_url).to start_with('http://localhost:7654/auth/result')
  end

  scenario 'sign in with VTR request for idv requires idv'
  scenario 'sign in with VTR request for idv with biometric requires idv with biometric'
end
