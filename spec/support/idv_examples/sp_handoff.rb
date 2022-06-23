shared_examples 'sp handoff after identity verification' do |sp|
  include SamlAuthHelper
  include IdvHelper
  include JavascriptDriverHelper

  let(:email) { 'test@test.com' }

  context 'sign up' do
    let(:user) { User.find_with_email(email) }

    it 'requires idv and hands off correctly', js: true do
      visit_idp_from_sp_with_ial2(sp)
      register_user(email)

      expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)

      complete_all_doc_auth_steps
      click_idv_continue
      fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
      click_continue
      acknowledge_and_confirm_personal_key

      expect(page).to have_content t(
        'titles.sign_up.completion_ial2',
        app_name: APP_NAME,
      )
      expect_csp_headers_to_be_present if sp == :oidc

      click_agree_and_continue

      expect(user.events.account_verified.size).to be(1)
      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  context 'unverified user sign in' do
    let(:user) { user_with_2fa }

    it 'requires idv and hands off successfully', js: true do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_path).to eq idv_doc_auth_step_path(step: :welcome)

      complete_all_doc_auth_steps
      click_idv_continue
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key

      expect(page).to have_content t(
        'titles.sign_up.completion_ial2',
        app_name: APP_NAME,
      )
      expect_csp_headers_to_be_present if sp == :oidc

      click_agree_and_continue

      expect(user.events.account_verified.size).to be(1)
      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  context 'verified user sign in', js: true do
    let(:user) { user_with_2fa }

    before do
      sign_in_and_2fa_user(user)
      complete_all_doc_auth_steps
      click_idv_continue
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key
      first(:link, t('links.sign_out')).click
    end

    it 'does not require verification and hands off successfully' do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect_csp_headers_to_be_present if sp == :oidc

      click_agree_and_continue

      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  context 'second time a user signs in to an SP', js: true do
    let(:user) { user_with_2fa }

    before do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      uncheck(t('forms.messages.remember_device'))

      fill_in_code_with_last_phone_otp
      click_submit_default
      complete_all_doc_auth_steps
      click_idv_continue
      fill_in 'Password', with: user.password
      click_continue
      acknowledge_and_confirm_personal_key
      click_agree_and_continue
      visit account_path
      first(:link, t('links.sign_out')).click
    end

    it 'does not require idv or requested attribute verification and hands off successfully' do
      visit_idp_from_sp_with_ial2(sp)
      sign_in_user(user)
      uncheck(t('forms.messages.remember_device'))

      expect_csp_headers_to_be_present if sp == :oidc

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  def expect_csp_headers_to_be_present
    # Selenium driver does not support response header inspection, but we should be able to expect
    # that the browser itself would respect CSP and refuse invalid form targets.
    return if javascript_enabled?
    expect(page.response_headers['Content-Security-Policy']).
      to(include('form-action \'self\' http://localhost:7654'))
  end

  def expect_successful_oidc_handoff
    redirect_uri = URI(current_url)
    redirect_params = Rack::Utils.parse_query(redirect_uri.query).with_indifferent_access

    expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    expect(redirect_params[:state]).to eq(@state)

    code = redirect_params[:code]
    expect(code).to be_present

    jwt_payload = {
      iss: @client_id,
      sub: @client_id,
      aud: api_openid_connect_token_url,
      jti: SecureRandom.hex,
      exp: 5.minutes.from_now.to_i,
    }

    client_assertion = JWT.encode(jwt_payload, client_private_key, 'RS256')
    client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

    Capybara.using_driver(:desktop_rack_test) do
      page.driver.post api_openid_connect_token_path,
                       grant_type: 'authorization_code',
                       code: code,
                       client_assertion_type: client_assertion_type,
                       client_assertion: client_assertion

      expect(page.status_code).to eq(200)
      token_response = JSON.parse(page.body).with_indifferent_access

      id_token = token_response[:id_token]
      expect(id_token).to be_present

      decoded_id_token, _headers = JWT.decode(
        id_token, sp_public_key, true, algorithm: 'RS256'
      ).map(&:with_indifferent_access)

      sub = decoded_id_token[:sub]
      expect(sub).to be_present
      expect(decoded_id_token[:nonce]).to eq(@nonce)
      expect(decoded_id_token[:aud]).to eq(@client_id)
      expect(decoded_id_token[:acr]).to eq(Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF)
      expect(decoded_id_token[:iss]).to eq(root_url)
      expect(decoded_id_token[:email]).to eq(user.confirmed_email_addresses.first.email)
      expect(decoded_id_token[:given_name]).to eq('FAKEY')
      expect(decoded_id_token[:social_security_number]).to eq(DocAuthHelper::GOOD_SSN)

      access_token = token_response[:access_token]
      expect(access_token).to be_present

      page.driver.get api_openid_connect_userinfo_path,
                      {},
                      'HTTP_AUTHORIZATION' => "Bearer #{access_token}"

      userinfo_response = JSON.parse(page.body).with_indifferent_access
      expect(userinfo_response[:sub]).to eq(sub)
      expect(AgencyIdentity.where(user_id: user.id, agency_id: 2).first.uuid).to eq(sub)
      expect(userinfo_response[:email]).to eq(user.confirmed_email_addresses.first.email)
      expect(userinfo_response[:given_name]).to eq('FAKEY')
      expect(userinfo_response[:social_security_number]).to eq(DocAuthHelper::GOOD_SSN)
    end
  end

  def expect_successful_saml_handoff
    profile_phone = user.active_profile.decrypt_pii(Features::SessionHelper::VALID_PASSWORD).phone
    xmldoc = SamlResponseDoc.new('feature', 'response_assertion')

    expect(AgencyIdentity.where(user_id: user.id, agency_id: 2).first.uuid).to eq(xmldoc.uuid)
    if javascript_enabled?
      expect(current_path).to eq test_saml_decode_assertion_path
    else
      expect(current_url).to eq @saml_authn_request
    end
    expect(xmldoc.phone_number.children.children.to_s).to eq(Phonelib.parse(profile_phone).e164)
  end

  def client_private_key
    @client_private_key ||= begin
      OpenSSL::PKey::RSA.new(
        File.read(Rails.root.join('keys', 'saml_test_sp.key')),
      )
    end
  end

  def sp_public_key
    page.driver.get api_openid_connect_certs_path

    expect(page.status_code).to eq(200)
    certs_response = JSON.parse(page.body).with_indifferent_access

    JWT::JWK.import(certs_response[:keys].first).public_key
  end
end
