shared_examples 'idv account creation' do |sp|
  it 'redirects to SP after IdV is complete', email: true do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    email = 'test@test.com'

    if sp == :saml
      saml_authn_request = auth_request.create(loa3_with_bundle_saml_settings)
      xmldoc = SamlResponseDoc.new('feature', 'response_assertion')
      visit saml_authn_request
    elsif sp == :oidc
      state = SecureRandom.hex
      client_id = 'urn:gov:gsa:openidconnect:sp:server'
      nonce = SecureRandom.hex
      visit_idp_from_sp_with_loa3(state: state, client_id: client_id, nonce: nonce)
    end

    register_user(email)

    expect(current_path).to eq verify_path

    click_idv_begin

    user = User.find_with_email(email)
    complete_idv_profile_ok(user.reload)
    click_acknowledge_personal_key

    expect(page).to have_content t(
      'titles.sign_up.completion_html',
      accent: t('titles.sign_up.loa3'),
      app: APP_NAME
    )
    within('.requested-attributes') do
      expect(page).to have_content t('help_text.requested_attributes.email')
      expect(page).to_not have_content t('help_text.requested_attributes.address')
      expect(page).to_not have_content t('help_text.requested_attributes.birthdate')
      expect(page).to have_content t('help_text.requested_attributes.full_name')
      expect(page).to have_content t('help_text.requested_attributes.phone')
      expect(page).to have_content t('help_text.requested_attributes.social_security_number')
    end

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_on I18n.t('forms.buttons.continue')

    expect(user.events.account_verified.size).to be(1)

    if sp == :saml
      user_access_key = user.unlock_user_access_key(Features::SessionHelper::VALID_PASSWORD)
      profile_phone = user.active_profile.decrypt_pii(user_access_key).phone

      expect(current_url).to eq saml_authn_request
      expect(xmldoc.phone_number.children.children.to_s).to eq(profile_phone)
    end

    if sp == :oidc
      redirect_uri = URI(current_url)
      redirect_params = Rack::Utils.parse_query(redirect_uri.query).with_indifferent_access

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
      expect(redirect_params[:state]).to eq(state)

      code = redirect_params[:code]
      expect(code).to be_present

      jwt_payload = {
        iss: client_id,
        sub: client_id,
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
      expect(decoded_id_token[:nonce]).to eq(nonce)
      expect(decoded_id_token[:aud]).to eq(client_id)
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
      expect(userinfo_response[:email]).to eq(user.email)
      expect(userinfo_response[:given_name]).to eq('José')
      expect(userinfo_response[:social_security_number]).to eq('666-66-1234')
    end
  end
end

def visit_idp_from_sp_with_loa3(state: SecureRandom.hex, client_id:, nonce:)
  visit openid_connect_authorize_path(
    client_id: client_id,
    response_type: 'code',
    acr_values: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
    scope: 'openid email profile:name phone social_security_number',
    redirect_uri: 'http://localhost:7654/auth/result',
    state: state,
    prompt: 'select_account',
    nonce: nonce
  )
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
