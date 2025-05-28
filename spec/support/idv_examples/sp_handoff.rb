RSpec.shared_examples 'sp handoff after identity verification' do |sp|
  include SamlAuthHelper
  include OidcAuthHelper
  include IdvHelper
  include JavascriptDriverHelper

  let(:email) { 'test@test.com' }

  context 'sign up' do
    let(:user) { User.find_with_email(email) }

    it 'requires idv and hands off correctly', js: true do
      visit_idp_from_sp_with_ial2(sp)
      register_user(email)

      expect(page).to have_current_path idv_welcome_path

      complete_all_doc_auth_steps_before_password_step
      fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
      click_continue
      acknowledge_and_confirm_personal_key

      expect(page).to have_content t(
        'titles.sign_up.completion_ial2',
        sp: 'Test SP',
      )
      expect_csp_headers_to_be_present if sp == :oidc

      click_agree_and_continue

      expect(user.events.account_verified.size).to be(1)
      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  context 'unverified user sign in' do
    let(:user) { user_with_totp_2fa }

    it 'requires idv and hands off successfully', js: true do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      fill_in_code_with_last_totp(user)
      click_submit_default

      expect(page).to have_current_path idv_welcome_path

      complete_all_doc_auth_steps_before_password_step
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key

      expect(page).to have_content t(
        'titles.sign_up.completion_ial2',
        sp: 'Test SP',
      )
      expect_csp_headers_to_be_present if sp == :oidc

      click_agree_and_continue

      expect(user.events.account_verified.size).to be(1)
      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  context 'verified user sign in', js: true do
    let(:user) { user_with_totp_2fa }

    before do
      sign_in_and_2fa_user(user)
      complete_all_doc_auth_steps_before_password_step
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key
      first(:button, t('links.sign_out')).click
    end

    it 'does not require verification and hands off successfully' do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      fill_in_code_with_last_totp(user)
      click_submit_default

      expect_csp_headers_to_be_present if sp == :oidc

      click_agree_and_continue

      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  context 'second time a user signs in to an SP', js: true do
    let(:user) { user_with_totp_2fa }

    before do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      uncheck(t('forms.messages.remember_device'))

      fill_in_code_with_last_totp(user)
      click_submit_default
      complete_all_doc_auth_steps_before_password_step
      click_idv_continue
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key
      click_agree_and_continue
      visit account_path
      first(:button, t('links.sign_out')).click
    end

    it 'does not require idv or requested attribute verification and hands off successfully' do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      uncheck(t('forms.messages.remember_device'))

      expect_csp_headers_to_be_present if sp == :oidc

      fill_in_code_with_last_totp(user)
      click_submit_default

      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  def expect_csp_headers_to_be_present
    # Selenium driver does not support response header inspection, but we should be able to expect
    # that the browser itself would respect CSP and refuse invalid form targets.
    return if javascript_enabled?
    expect(page.response_headers['Content-Security-Policy'])
      .to(include('form-action \'self\' http://localhost:7654'))
  end

  def expect_successful_oidc_handoff
    token_response = oidc_decoded_token
    decoded_id_token = oidc_decoded_id_token

    Capybara.using_driver(:desktop_rack_test) do
      sub = decoded_id_token[:sub]
      expect(sub).to be_present
      expect(decoded_id_token[:nonce]).to eq(@nonce)
      expect(decoded_id_token[:aud]).to eq(@client_id)
      expect(decoded_id_token[:acr]).to eq(Saml::Idp::Constants::IAL_VERIFIED_ACR)
      expect(decoded_id_token[:iss]).to eq(root_url)
      expect(decoded_id_token[:email]).to eq(user.last_sign_in_email_address.email)
      expect(decoded_id_token[:given_name]).to eq('MICHELE')
      expect(decoded_id_token[:social_security_number]).to eq(DocAuthHelper::GOOD_SSN)

      access_token = token_response[:access_token]
      expect(access_token).to be_present

      page.driver.get api_openid_connect_userinfo_path,
                      {},
                      'HTTP_AUTHORIZATION' => "Bearer #{access_token}"

      userinfo_response = JSON.parse(page.body).with_indifferent_access
      expect(userinfo_response[:sub]).to eq(sub)
      expect(AgencyIdentity.where(user_id: user.id, agency_id: 2).first.uuid).to eq(sub)
      expect(userinfo_response[:email]).to eq(user.last_sign_in_email_address.email)
      expect(userinfo_response[:given_name]).to eq('MICHELE')
      expect(userinfo_response[:social_security_number]).to eq(DocAuthHelper::GOOD_SSN)
    end
  end

  def expect_successful_saml_handoff
    profile_phone = user.active_profile.decrypt_pii(Features::SessionHelper::VALID_PASSWORD).phone
    xmldoc = SamlResponseDoc.new('feature', 'response_assertion')

    expect(AgencyIdentity.where(user_id: user.id, agency_id: 2).first.uuid).to eq(xmldoc.uuid)
    if javascript_enabled?
      expect(page).to have_current_path test_saml_decode_assertion_path
    else
      expect(current_url).to eq @saml_authn_request
    end
    expect(xmldoc.phone_number.children.children.to_s).to eq(Phonelib.parse(profile_phone).e164)
  end
end
