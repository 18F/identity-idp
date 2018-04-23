shared_examples 'sp handoff after identity verification' do |sp|
  include SamlAuthHelper
  include IdvHelper

  before do
    allow(Figaro.env).to receive(:enable_agency_based_uuids).and_return('true')
    allow(Figaro.env).to receive(:agencies_with_agency_based_uuids).and_return('1,2,3')
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
  end

  let(:email) { 'test@test.com' }

  context 'sign up' do
    let(:user) { User.find_with_email(email) }

    it 'requires idv and hands off correctly' do
      visit_idp_from_sp_with_loa3(sp)
      register_user(email)

      expect(current_path).to eq verify_path

      click_idv_begin
      complete_idv_profile_ok(user)
      click_acknowledge_personal_key

      expect(page).to have_content t(
        'titles.sign_up.verified',
        app: APP_NAME
      )
      expect_csp_headers_to_be_present if sp == :oidc

      click_on I18n.t('forms.buttons.continue')

      expect(user.events.account_verified.size).to be(1)
      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  context 'unverified user sign in' do
    let(:user) { user_with_2fa }

    it 'requires idv and hands off successfully' do
      visit_idp_from_sp_with_loa3(sp)
      click_link t('links.sign_in')
      sign_in_user(user)
      click_submit_default

      expect(current_path).to eq verify_path

      click_idv_begin
      complete_idv_profile_ok(user)
      click_acknowledge_personal_key

      expect(page).to have_content t(
        'titles.sign_up.verified',
        app: APP_NAME
      )
      expect_csp_headers_to_be_present if sp == :oidc

      click_on I18n.t('forms.buttons.continue')

      expect(user.events.account_verified.size).to be(1)
      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  context 'verified user sign in' do
    let(:user) { user_with_2fa }

    before do
      sign_in_and_2fa_user(user)
      visit verify_session_path
      complete_idv_profile_ok(user)
      click_acknowledge_personal_key
      first(:link, t('links.sign_out')).click
    end

    it 'does not require verification and hands off successfully' do
      visit_idp_from_sp_with_loa3(sp)
      click_link t('links.sign_in')
      sign_in_user(user)
      click_submit_default

      expect_csp_headers_to_be_present if sp == :oidc

      click_on I18n.t('forms.buttons.continue')

      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  context 'second time a user signs in to an SP' do
    let(:user) { user_with_2fa }

    before do
      visit_idp_from_sp_with_loa3(sp)
      click_link t('links.sign_in')
      sign_in_user(user)
      click_submit_default
      click_idv_begin
      complete_idv_profile_ok(user)
      click_acknowledge_personal_key
      click_on I18n.t('forms.buttons.continue')
      visit account_path
      first(:link, t('links.sign_out')).click
      click_submit_default if sp == :saml # SAML SLO request
    end

    it 'does not require idv or requested attribute verification and hands off successfully' do
      visit_idp_from_sp_with_loa3(sp)
      click_link t('links.sign_in')
      sign_in_user(user)

      expect_csp_headers_to_be_present if sp == :oidc

      click_submit_default

      expect_successful_oidc_handoff if sp == :oidc
      expect_successful_saml_handoff if sp == :saml
    end
  end

  def expect_csp_headers_to_be_present
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
    expect(decoded_id_token[:acr]).to eq(Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF)
    expect(decoded_id_token[:iss]).to eq(root_url)
    expect(decoded_id_token[:email]).to eq(user.email)
    expect(decoded_id_token[:given_name]).to eq('José')
    expect(decoded_id_token[:social_security_number]).to eq('666-66-1234')

    access_token = token_response[:access_token]
    expect(access_token).to be_present

    page.driver.get api_openid_connect_userinfo_path,
                    {},
                    'HTTP_AUTHORIZATION' => "Bearer #{access_token}"

    userinfo_response = JSON.parse(page.body).with_indifferent_access
    expect(userinfo_response[:sub]).to eq(sub)
    expect(AgencyIdentity.where(user_id: user.id, agency_id: 2).first.uuid).to eq(sub)
    expect(userinfo_response[:email]).to eq(user.email)
    expect(userinfo_response[:given_name]).to eq('José')
    expect(userinfo_response[:social_security_number]).to eq('666-66-1234')
  end

  def expect_successful_saml_handoff
    user_access_key = user.unlock_user_access_key(Features::SessionHelper::VALID_PASSWORD)
    profile_phone = user.active_profile.decrypt_pii(user_access_key).phone
    xmldoc = SamlResponseDoc.new('feature', 'response_assertion')

    expect(AgencyIdentity.where(user_id: user.id, agency_id: 2).first.uuid).to eq(xmldoc.uuid)
    expect(current_url).to eq @saml_authn_request
    expect(xmldoc.phone_number.children.children.to_s).to eq(profile_phone)
  end

  def client_private_key
    @client_private_key ||= begin
      OpenSSL::PKey::RSA.new(
        File.read(Rails.root.join('keys', 'saml_test_sp.key'))
      )
    end
  end

  def sp_public_key
    page.driver.get api_openid_connect_certs_path

    expect(page.status_code).to eq(200)
    certs_response = JSON.parse(page.body).with_indifferent_access

    JSON::JWK.new(certs_response[:keys].first).to_key
  end
end
