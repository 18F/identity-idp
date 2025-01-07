require 'rails_helper'

RSpec.feature 'SAML requests using VTR' do
  include SamlAuthHelper
  include IdvHelper
  include DocAuthHelper
  include WebAuthnHelper

  let(:use_vot_in_sp_requests) { true }

  before do
    allow(IdentityConfig.store).to receive(
      :use_vot_in_sp_requests,
    ).and_return(
      use_vot_in_sp_requests,
    )
  end

  scenario 'sign in with VTR request for authentication' do
    user = create(:user, :fully_registered)

    visit_saml_authn_request_url(
      overrides: {
        authn_context: 'C1',
      },
    )
    sign_in_live_with_2fa(user)
    click_submit_default
    click_agree_and_continue
    click_submit_default

    expect_successful_saml_redirect

    xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
    expect(xmldoc.assertion_statement_node.content).to eq('C1')
    expect(xmldoc.attribute_node_for('vot').content).to eq('C1')
    expect(xmldoc.attribute_node_for('ial')).to be_nil
    expect(xmldoc.attribute_node_for('aal')).to be_nil

    email = xmldoc.attribute_node_for('email').content
    expect(user.email_addresses.first.email).to eq(email)
  end

  scenario 'sign in with VTR request for AAL2 disables remember device' do
    user = create(:user, :fully_registered)

    # Sign in and remember device
    sign_in_user(user)
    check t('forms.messages.remember_device')
    fill_in_code_with_last_phone_otp
    click_submit_default
    first(:button, t('links.sign_out')).click

    visit_saml_authn_request_url(
      overrides: {
        authn_context: 'C1.C2',
      },
    )
    sign_in_user(user)

    # MFA is required despite remember device
    expect(page).to have_current_path(login_two_factor_path(otp_delivery_preference: :sms))
    fill_in_code_with_last_phone_otp
    click_submit_default

    click_submit_default
    click_agree_and_continue
    click_submit_default
    expect_successful_saml_redirect
  end

  scenario 'sign in with VTR request for phishing-resistance requires phishing-resistanc auth' do
    mock_webauthn_setup_challenge
    user = create(:user, :fully_registered)

    visit_saml_authn_request_url(
      overrides: {
        authn_context: 'C1.Ca',
      },
    )

    sign_in_live_with_2fa(user)

    # More secure MFA is required
    expect(page).to have_current_path(authentication_methods_setup_path)
    expect(page).to have_content(t('two_factor_authentication.two_factor_aal3_choice_intro'))

    # User must setup phishing-resistant auth
    select_2fa_option('webauthn', visible: :all)
    fill_in_nickname_and_click_continue
    mock_press_button_on_hardware_key_on_setup

    click_agree_and_continue
    click_submit_default
    expect_successful_saml_redirect
  end

  scenario 'sign in with VTR request for HSDP12 auth requires PIV/CAC setup' do
    allow(Identity::Hostdata).to receive(:env).and_return('test')
    allow(Identity::Hostdata).to receive(:domain).and_return('example.com')

    stub_piv_cac_service

    user = create(:user, :fully_registered)

    visit_saml_authn_request_url(
      overrides: {
        authn_context: 'C1.Cb',
      },
    )

    sign_in_live_with_2fa(user)

    # More secure MFA is required
    expect(page).to have_current_path(authentication_methods_setup_path)
    expect(page).to have_content(t('two_factor_authentication.two_factor_hspd12_choice_intro'))

    # User must setup PIV/CAC before continuing
    select_2fa_option('piv_cac')
    fill_in t('instructions.mfa.piv_cac.step_1'), with: 'Card'
    click_on t('forms.piv_cac_setup.submit')
    follow_piv_cac_redirect

    click_agree_and_continue
    click_submit_default
    expect_successful_saml_redirect
  end

  scenario 'sign in with VTR request for idv requires idv', :js do
    user = create(:user, :fully_registered)

    visit_saml_authn_request_url(
      overrides: {
        issuer: sp1_issuer,
        authn_context: 'C1.C2.P1',
      },
    )
    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(idv_welcome_path)

    complete_all_doc_auth_steps_before_password_step(with_selfie: false)
    fill_in 'Password', with: user.password
    click_continue
    acknowledge_and_confirm_personal_key
    click_agree_and_continue

    expect_successful_saml_redirect
  end

  scenario 'sign in with VTR request for idv includes proofed attributes' do
    pii = {
      first_name: 'Jonathan',
      ssn: '900-66-6666',
    }
    user = create(:user, :fully_registered)
    create(:profile, :active, user: user, pii: pii)

    visit_saml_authn_request_url(
      overrides: {
        issuer: sp1_issuer,
        authn_context: [
          'C1.C2.P1',
          "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}first_name",
          "#{Saml::Idp::Constants::REQUESTED_ATTRIBUTES_CLASSREF}ssn",
        ],
      },
    )
    sign_in_live_with_2fa(user)
    click_submit_default
    click_agree_and_continue
    click_submit_default

    expect_successful_saml_redirect

    xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
    expect(xmldoc.assertion_statement_node.content).to eq('C1.C2.P1')
    expect(xmldoc.attribute_node_for('vot').content).to eq('C1.C2.P1')
    expect(xmldoc.attribute_node_for('ial')).to be_nil
    expect(xmldoc.attribute_node_for('aal')).to be_nil

    first_name = xmldoc.attribute_node_for('first_name').content
    ssn = xmldoc.attribute_node_for('ssn').content

    expect(first_name).to eq(pii[:first_name])
    expect(ssn).to eq(pii[:ssn])
  end

  scenario 'sign in with VTR request for idv with facial match requires idv with facial match',
           :js do
    user = create(:user, :proofed)
    user.active_profile.update!(idv_level: :legacy_unsupervised)

    visit_saml_authn_request_url(
      overrides: {
        issuer: sp1_issuer,
        authn_context: 'C1.C2.P1.Pb',
      },
    )
    sign_in_live_with_2fa(user)

    expect(page).to have_current_path(idv_welcome_path)

    complete_all_doc_auth_steps_before_password_step(with_selfie: true)
    fill_in 'Password', with: user.password
    click_continue
    acknowledge_and_confirm_personal_key
    click_agree_and_continue

    expect_successful_saml_redirect
  end

  def expect_successful_saml_redirect
    if javascript_enabled?
      expect(page).to have_current_path(test_saml_decode_assertion_path)
    else
      expect(page).to have_current_path(
        api_saml_finalauthpost_path(path_year: SamlAuthHelper::PATH_YEAR),
      )
    end
  end
end
