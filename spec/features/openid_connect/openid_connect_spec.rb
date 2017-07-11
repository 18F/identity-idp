require 'rails_helper'

feature 'OpenID Connect' do
  include IdvHelper

  context 'with client_secret_jwt' do
    it 'succeeds' do
      client_id = 'urn:gov:gsa:openidconnect:sp:server'
      state = SecureRandom.hex
      nonce = SecureRandom.hex

      visit openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email profile:name social_security_number',
        redirect_uri: 'http://localhost:7654/auth/result',
        state: state,
        prompt: 'select_account',
        nonce: nonce
      )

      user = create(:profile, :active, :verified,
                    pii: { first_name: 'John', ssn: '111223333' }).user

      sign_in_live_with_2fa(user)

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
      expect(decoded_id_token[:given_name]).to eq('John')
      expect(decoded_id_token[:social_security_number]).to eq('111223333')

      access_token = token_response[:access_token]
      expect(access_token).to be_present

      page.driver.get api_openid_connect_userinfo_path,
                      {},
                      'HTTP_AUTHORIZATION' => "Bearer #{access_token}"

      userinfo_response = JSON.parse(page.body).with_indifferent_access
      expect(userinfo_response[:sub]).to eq(sub)
      expect(userinfo_response[:email]).to eq(user.email)
      expect(userinfo_response[:given_name]).to eq('John')
      expect(userinfo_response[:social_security_number]).to eq('111223333')
    end

    it 'auto-allows with a second authorization and sets the correct CSP headers' do
      client_id = 'urn:gov:gsa:openidconnect:sp:server'
      user = user_with_2fa

      IdentityLinker.new(user, client_id).link_identity

      visit openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email',
        redirect_uri: 'http://localhost:7654/auth/result',
        state: SecureRandom.hex,
        nonce: SecureRandom.hex,
        prompt: 'select_account'
      )

      sp_request_id = ServiceProviderRequest.last.uuid
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      sign_in_user(user)

      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))

      click_submit_default

      expect(current_url).to start_with('http://localhost:7654/auth/result')
      expect(ServiceProviderRequest.from_uuid(sp_request_id)).
        to be_a NullServiceProviderRequest
      expect(page.get_rack_session.keys).to_not include('sp')
    end

    it 'auto-allows and sets the correct CSP headers after an incorrect OTP' do
      client_id = 'urn:gov:gsa:openidconnect:sp:server'
      user = user_with_2fa

      IdentityLinker.new(user, client_id).link_identity

      visit openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email',
        redirect_uri: 'http://localhost:7654/auth/result',
        state: SecureRandom.hex,
        nonce: SecureRandom.hex,
        prompt: 'select_account'
      )

      sp_request_id = ServiceProviderRequest.last.uuid
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      sign_in_user(user)

      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))

      fill_in :code, with: 'wrong otp'
      click_submit_default

      expect(page).to have_content(t('devise.two_factor_authentication.invalid_otp'))
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
      click_submit_default

      expect(current_url).to start_with('http://localhost:7654/auth/result')
      expect(ServiceProviderRequest.from_uuid(sp_request_id)).
        to be_a NullServiceProviderRequest
      expect(page.get_rack_session.keys).to_not include('sp')
    end
  end

  context 'with PCKE' do
    it 'succeeds with client authentication via PKCE' do
      client_id = 'urn:gov:gsa:openidconnect:test'
      state = SecureRandom.hex
      nonce = SecureRandom.hex
      code_verifier = SecureRandom.hex
      code_challenge = Digest::SHA256.base64digest(code_verifier)

      visit openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email',
        redirect_uri: 'gov.gsa.openidconnect.test://result',
        state: state,
        prompt: 'select_account',
        nonce: nonce,
        code_challenge: code_challenge,
        code_challenge_method: 'S256'
      )

      _user = sign_in_live_with_2fa
      expect(page.html).to_not include(code_challenge)

      redirect_uri = URI(current_url)
      redirect_params = Rack::Utils.parse_query(redirect_uri.query).with_indifferent_access

      expect(redirect_uri.to_s).to start_with('gov.gsa.openidconnect.test://result')
      expect(redirect_params[:state]).to eq(state)

      code = redirect_params[:code]
      expect(code).to be_present

      page.driver.post api_openid_connect_token_path,
                       grant_type: 'authorization_code',
                       code: code,
                       code_verifier: code_verifier

      expect(page.status_code).to eq(200)
      token_response = JSON.parse(page.body).with_indifferent_access

      id_token = token_response[:id_token]
      expect(id_token).to be_present
    end

    it 'continues to the branded authorization page on first-time signup', email: true do
      client_id = 'urn:gov:gsa:openidconnect:test'
      email = 'test@test.com'

      perform_in_browser(:one) do
        state = SecureRandom.hex

        visit openid_connect_authorize_path(
          client_id: client_id,
          response_type: 'code',
          acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
          scope: 'openid email',
          redirect_uri: 'gov.gsa.openidconnect.test://result',
          state: state,
          nonce: SecureRandom.hex,
          prompt: 'select_account',
          code_challenge: Digest::SHA256.base64digest(SecureRandom.hex),
          code_challenge_method: 'S256'
        )

        sp_content = [
          'Example iOS App',
          t('headings.create_account_with_sp.sp_text'),
        ].join(' ')

        expect(page).to have_content(sp_content)

        cancel_callback_url =
          "gov.gsa.openidconnect.test://result?error=access_denied&state=#{state}"

        expect(page).to have_link(
          t('links.back_to_sp', sp: 'Example iOS App'), href: cancel_callback_url
        )

        sign_up_user_from_sp_without_confirming_email(email)
      end

      sp_request_id = ServiceProviderRequest.last.uuid

      perform_in_browser(:two) do
        confirm_email_in_a_different_browser(email)

        click_button t('forms.buttons.continue')
        redirect_uri = URI(current_url)
        expect(redirect_uri.to_s).to start_with('gov.gsa.openidconnect.test://result')
        expect(ServiceProviderRequest.from_uuid(sp_request_id)).
          to be_a NullServiceProviderRequest
        expect(page.get_rack_session.keys).to_not include('sp')
      end
    end
  end

  context 'LOA3 continuation' do
    let(:user) { profile.user }
    let(:otp) { 'abc123' }
    let(:profile) do
      create(
        :profile,
        deactivation_reason: :verification_pending,
        phone_confirmed: phone_confirmed,
        pii: { otp: otp, ssn: '6666', dob: '1920-01-01' }
      )
    end
    let(:oidc_auth_url) do
      client_id = 'urn:gov:gsa:openidconnect:sp:server'
      state = SecureRandom.hex
      nonce = SecureRandom.hex

      openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email profile:name social_security_number',
        redirect_uri: 'http://localhost:7654/auth/result',
        state: state,
        prompt: 'select_account',
        nonce: nonce
      )
    end

    context 'USPS verification' do
      let(:phone_confirmed) { false }

      it 'prompts to finish verifying profile, then redirects to SP' do
        allow(FeatureManagement).to receive(:reveal_usps_code?).and_return(true)
        visit oidc_auth_url

        sign_in_live_with_2fa(user)

        click_button t('forms.verify_profile.submit')

        expect(current_path).to eq(sign_up_completed_path)
        find('input').click

        redirect_uri = URI(current_url)

        expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
      end
    end

    context 'phone verification' do
      let(:phone_confirmed) { true }

      it 'prompts to finish verifying profile, then redirects to SP' do
        visit oidc_auth_url

        sign_in_live_with_2fa(user)
        enter_correct_otp_code_for_user(user)

        redirect_uri = URI(current_url)
        expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
      end
    end
  end

  context 'LOA3 signup' do
    it 'redirects back to SP', email: true do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)

      client_id = 'urn:gov:gsa:openidconnect:sp:server'
      state = SecureRandom.hex
      nonce = SecureRandom.hex
      email = 'test@test.com'

      visit openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::LOA3_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email profile:name social_security_number',
        redirect_uri: 'http://localhost:7654/auth/result',
        state: state,
        prompt: 'select_account',
        nonce: nonce
      )

      click_link t('sign_up.registrations.create_account')
      submit_form_with_valid_email
      click_confirmation_link_in_email(email)
      submit_form_with_valid_password
      set_up_2fa_with_valid_phone
      enter_2fa_code
      click_on 'Yes'
      user = User.find_with_email(email)
      complete_idv_profile_ok(user.reload)
      click_acknowledge_personal_key

      within('.requested-attributes') do
        expect(page).to have_content t('help_text.requested_attributes.email')
        expect(page).to_not have_content t('help_text.requested_attributes.address')
        expect(page).to_not have_content t('help_text.requested_attributes.birthdate')
        expect(page).to have_content t('help_text.requested_attributes.full_name')
        expect(page).to_not have_content t('help_text.requested_attributes.phone')
        expect(page).to have_content t('help_text.requested_attributes.social_security_number')
      end

      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))

      click_on I18n.t('forms.buttons.continue')

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

  context 'visiting IdP via SP, then going back to SP and visiting IdP again' do
    it 'maintains the request_id in the params' do
      visit_idp_from_sp_with_loa1
      sp_request_id = ServiceProviderRequest.last.uuid

      expect(current_url).to eq sign_up_start_url(request_id: sp_request_id)

      visit_idp_from_sp_with_loa1

      expect(current_url).to eq sign_up_start_url(request_id: sp_request_id)
    end
  end

  context 'going back to the SP' do
    it 'links back to the SP from the sign in page' do
      state = SecureRandom.hex

      visit_idp_from_sp_with_loa1(state: state)

      click_link t('links.sign_in')

      cancel_callback_url = "http://localhost:7654/auth/result?error=access_denied&state=#{state}"

      expect(page).to have_link(
        "‹ #{t('links.back_to_sp', sp: 'Test SP')}", href: cancel_callback_url
      )
    end
  end

  context 'signing out' do
    it 'redirects back to the client app and destroys the session' do
      id_token = sign_in_get_id_token

      state = SecureRandom.hex

      visit openid_connect_logout_path(
        post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/logout',
        state: state,
        id_token_hint: id_token
      )

      current_url_no_port = URI(current_url).tap { |uri| uri.port = nil }.to_s
      expect(current_url_no_port).to eq("gov.gsa.openidconnect.test://result/logout?state=#{state}")

      visit account_path
      expect(page).to_not have_content(t('headings.account.login_info'))
      expect(page).to have_content(t('headings.sign_in_without_sp'))
    end
  end

  context 'canceling sign in with active identities present' do
    it 'signs the user out and returns to the home page' do
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)

      user = create(:user, :signed_up)

      visit_idp_from_sp_with_loa1
      click_link t('links.sign_in')
      fill_in_credentials_and_submit(user.email, user.password)
      click_submit_default
      visit destroy_user_session_url

      visit_idp_from_sp_with_loa1
      click_link t('links.sign_in')
      fill_in_credentials_and_submit(user.email, user.password)
      sp_request_id = ServiceProviderRequest.last.uuid
      sp = ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:sp:server')
      click_link t('links.cancel')

      expect(current_url).to eq sign_up_start_url(request_id: sp_request_id)
      expect(page).to have_content t('links.back_to_sp', sp: sp.friendly_name)
    end
  end

  def visit_idp_from_sp_with_loa1(state: SecureRandom.hex)
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    nonce = SecureRandom.hex

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'select_account',
      nonce: nonce
    )
  end

  def sign_in_get_id_token
    client_id = 'urn:gov:gsa:openidconnect:test'
    state = SecureRandom.hex
    nonce = SecureRandom.hex
    code_verifier = SecureRandom.hex
    code_challenge = Digest::SHA256.base64digest(code_verifier)

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::LOA1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'gov.gsa.openidconnect.test://result/auth',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
      code_challenge: code_challenge,
      code_challenge_method: 'S256'
    )

    _user = sign_in_live_with_2fa

    redirect_uri = URI(current_url)
    redirect_params = Rack::Utils.parse_query(redirect_uri.query).with_indifferent_access
    code = redirect_params[:code]
    expect(code).to be_present

    page.driver.post api_openid_connect_token_path,
                     grant_type: 'authorization_code',
                     code: code,
                     code_verifier: code_verifier
    expect(page.status_code).to eq(200)

    token_response = JSON.parse(page.body).with_indifferent_access
    token_response[:id_token]
  end

  def sp_public_key
    page.driver.get api_openid_connect_certs_path

    expect(page.status_code).to eq(200)
    certs_response = JSON.parse(page.body).with_indifferent_access

    JSON::JWK.new(certs_response[:keys].first).to_key
  end

  def client_private_key
    @client_private_key ||= begin
      OpenSSL::PKey::RSA.new(
        File.read(Rails.root.join('keys', 'saml_test_sp.key'))
      )
    end
  end
end
