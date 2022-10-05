require 'rails_helper'
require 'query_tracker'

describe 'OpenID Connect' do
  include IdvHelper
  include OidcAuthHelper
  include DocAuthHelper

  it 'sets the sp_issuer cookie' do
    visit_idp_from_ial1_oidc_sp

    cookie = cookies.find { |c| c.name == 'sp_issuer' }.value
    expect(cookie).to eq(OidcAuthHelper::OIDC_ISSUER)
  end

  it 'receives an ID token with a kid that matches the certs endpooint' do
    id_token = sign_in_get_id_token

    _payload, headers = JWT.decode(
      id_token, sp_public_key, true, algorithm: 'RS256'
    ).map(&:with_indifferent_access)

    kid = headers[:kid]
    expect(certs_response[:keys].find { |key| key[:kid] == kid }).to be
  end

  context 'with client_secret_jwt' do
    it 'succeeds with prompt select_account and no prior session' do
      oidc_end_client_secret_jwt(prompt: 'select_account')
    end

    it 'succeeds in returning back to sp with prompt select_account and prior session' do
      user = oidc_end_client_secret_jwt(prompt: 'select_account')
      oidc_end_client_secret_jwt(prompt: 'select_account', user: user, redirs_to: '/auth/result')
      expect(current_url).to include('?code=')
    end

    it 'succeeds with no prompt and no prior session like select_account' do
      oidc_end_client_secret_jwt
    end

    it 'succeeds in returning back to sp with no prompt and prior session like select_account' do
      user = oidc_end_client_secret_jwt
      oidc_end_client_secret_jwt(user: user, redirs_to: '/auth/result')
      expect(current_url).to include('?code=')
    end

    it 'succeeds with prompt login and no prior session' do
      oidc_end_client_secret_jwt(prompt: 'login')
    end

    it 'succeeds in forcing login with prompt login and prior session' do
      user = oidc_end_client_secret_jwt(prompt: 'login')
      travel_to((IdentityConfig.store.sp_handoff_bounce_max_seconds + 1).seconds.from_now) do
        oidc_end_client_secret_jwt(prompt: 'login', user: user)
      end
    end

    it 'succeeds with prompt select_account no prior session and bad Referer' do
      Capybara.current_session.driver.header 'Referer', 'bad'
      oidc_end_client_secret_jwt(prompt: 'select_account')
    end

    it 'succeeds with prompt login no prior session and bad Referer' do
      Capybara.current_session.driver.header 'Referer', 'bad'
      oidc_end_client_secret_jwt(prompt: 'login')
    end

    it 'fails with prompt login if not allowed for SP' do
      visit_idp_from_ial1_oidc_sp(
        prompt: 'login',
        client_id: 'urn:gov:gsa:openidconnect:test_prompt_login_banned',
      )

      expect(current_path).to eq(openid_connect_authorize_path)
      expect(page).to have_content(t('openid_connect.authorization.errors.prompt_invalid'))
    end

    it 'returns invalid request with bad prompt parameter' do
      oidc_end_client_secret_jwt(prompt: 'aaa', redirs_to: '/auth/result')
      expect(current_url).to include('?error=invalid_request')
    end

    it 'returns invalid request with a blank prompt parameter' do
      oidc_end_client_secret_jwt(prompt: '', redirs_to: '/auth/result')
      expect(current_url).to include('?error=invalid_request')
    end

    it 'auto-allows with a second authorization and includes redirect_uris in CSP headers' do
      client_id = 'urn:gov:gsa:openidconnect:sp:server'
      service_provider = build(:service_provider, issuer: client_id)
      user = user_with_2fa

      IdentityLinker.new(user, service_provider).link_identity
      user.identities.last.update!(verified_attributes: ['email'])

      visit_idp_from_ial1_oidc_sp(client_id: client_id, prompt: 'select_account')
      sign_in_user(user)

      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654 https://example.com'))

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_url).to start_with('http://localhost:7654/auth/result')
      expect(page.get_rack_session.keys).to include('sp')
    end

    it 'auto-allows and includes redirect_uris in CSP headers after an incorrect OTP' do
      client_id = 'urn:gov:gsa:openidconnect:sp:server'
      service_provider = build(:service_provider, issuer: client_id)
      user = user_with_2fa

      IdentityLinker.new(user, service_provider).link_identity
      user.identities.last.update!(verified_attributes: ['email'])

      visit_idp_from_ial1_oidc_sp(client_id: client_id, prompt: 'select_account')
      sign_in_user(user)

      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654 https://example.com'))

      fill_in :code, with: 'wrong otp'
      click_submit_default

      expect(page).to have_content(t('two_factor_authentication.invalid_otp'))
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654 https://example.com'))

      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(current_url).to start_with('http://localhost:7654/auth/result')
      expect(page.get_rack_session.keys).to include('sp')
    end
  end

  context 'when accepting id_token_hint in logout' do
    before do
      allow(IdentityConfig.store).to receive(:reject_id_token_hint_in_logout).
        and_return(false)
    end

    context 'when sending id_token_hint' do
      it 'logout destroys the session' do
        id_token = sign_in_get_id_token

        state = SecureRandom.hex

        visit openid_connect_logout_path(
          post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/signout',
          state: state,
          id_token_hint: id_token,
        )

        visit account_path
        expect(page).to_not have_content(t('headings.account.login_info'))
        expect(page).to have_content(t('headings.sign_in_without_sp'))
      end

      it 'logout does not require state' do
        id_token = sign_in_get_id_token

        visit openid_connect_logout_path(
          post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/signout',
          id_token_hint: id_token,
        )

        visit account_path
        expect(page).to_not have_content(t('headings.account.login_info'))
        expect(page).to have_content(t('headings.sign_in_without_sp'))
      end
    end

    context 'when sending client_id' do
      it 'logout destroys the session when confirming logout' do
        service_provider = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:test')
        sign_in_get_id_token(client_id: service_provider.issuer)

        state = SecureRandom.hex

        visit openid_connect_logout_path(
          client_id: service_provider.issuer,
          post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/signout',
          state: state,
        )
        expect(page).to have_content(
          t(
            'openid_connect.logout.heading_with_sp',
            app_name: APP_NAME,
            service_provider_name: service_provider.friendly_name,
          ),
        )
        click_button t('openid_connect.logout.confirm', app_name: APP_NAME)

        visit account_path
        expect(page).to_not have_content(t('headings.account.login_info'))
        expect(page).to have_content(t('headings.sign_in_without_sp'))
      end

      it 'logout does not require state' do
        service_provider = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:test')
        sign_in_get_id_token(client_id: service_provider.issuer)

        visit openid_connect_logout_path(
          client_id: service_provider.issuer,
          post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/signout',
        )
        expect(page).to have_content(
          t(
            'openid_connect.logout.heading_with_sp',
            app_name: APP_NAME,
            service_provider_name: service_provider.friendly_name,
          ),
        )
        click_button t('openid_connect.logout.confirm', app_name: APP_NAME)

        visit account_path
        expect(page).to_not have_content(t('headings.account.login_info'))
        expect(page).to have_content(t('headings.sign_in_without_sp'))
      end

      it 'does not destroy the session and redirects to account page when denying logout' do
        service_provider = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:test')
        sign_in_get_id_token(client_id: service_provider.issuer)

        state = SecureRandom.hex

        visit openid_connect_logout_path(
          client_id: service_provider.issuer,
          post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/signout',
          state: state,
        )
        expect(page).to have_content(
          t(
            'openid_connect.logout.heading_with_sp',
            app_name: APP_NAME,
            service_provider_name: service_provider.friendly_name,
          ),
        )
        click_link t('openid_connect.logout.deny')

        expect(page).to have_content(t('headings.account.login_info'))
      end
    end
  end

  context 'when rejecting id_token_hint in logout' do
    before do
      allow(IdentityConfig.store).to receive(:reject_id_token_hint_in_logout).
        and_return(true)
    end

    it 'logout destroys the session when confirming logout' do
      service_provider = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:test')
      sign_in_get_id_token(client_id: service_provider.issuer)

      state = SecureRandom.hex

      visit openid_connect_logout_path(
        client_id: service_provider.issuer,
        post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/signout',
        state: state,
      )
      expect(page).to have_content(
        t(
          'openid_connect.logout.heading_with_sp',
          app_name: APP_NAME,
          service_provider_name: service_provider.friendly_name,
        ),
      )
      click_button t('openid_connect.logout.confirm', app_name: APP_NAME)

      visit account_path
      expect(page).to_not have_content(t('headings.account.login_info'))
      expect(page).to have_content(t('headings.sign_in_without_sp'))
    end

    it 'logout does not require state' do
      service_provider = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:test')
      sign_in_get_id_token(client_id: service_provider.issuer)

      visit openid_connect_logout_path(
        client_id: service_provider.issuer,
        post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/signout',
      )
      expect(page).to have_content(
        t(
          'openid_connect.logout.heading_with_sp',
          app_name: APP_NAME,
          service_provider_name: service_provider.friendly_name,
        ),
      )
      click_button t('openid_connect.logout.confirm', app_name: APP_NAME)

      visit account_path
      expect(page).to_not have_content(t('headings.account.login_info'))
      expect(page).to have_content(t('headings.sign_in_without_sp'))
    end

    it 'logout rejects requests that include id_token_hint' do
      id_token = sign_in_get_id_token

      state = SecureRandom.hex

      visit openid_connect_logout_path(
        id_token_hint: id_token,
        post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/signout',
        state: state,
      )

      current_url_no_port = URI(current_url).tap { |uri| uri.port = nil }.to_s
      expect(current_url_no_port).to include(
        "http://www.example.com/openid_connect/logout?id_token_hint=#{id_token}",
      )
      expect(page).to have_content(t('openid_connect.logout.errors.id_token_hint_present'))
    end
  end

  it 'returns verified_at in an ial1 session if requested', driver: :mobile_rack_test do
    user = user_with_2fa
    profile = create(
      :profile, :active, :verified,
      pii: { first_name: 'John', ssn: '111223333' },
      user: user
    )

    token_response = sign_in_get_token_response(
      user: user,
      scope: 'openid email profile:verified_at',
      handoff_page_steps: proc do
        expect(page).to have_content(t('help_text.requested_attributes.verified_at'))

        click_agree_and_continue
      end,
    )

    access_token = token_response[:access_token]
    expect(access_token).to be_present

    page.driver.get api_openid_connect_userinfo_path,
                    {},
                    'HTTP_AUTHORIZATION' => "Bearer #{access_token}"

    userinfo_response = JSON.parse(page.body).with_indifferent_access
    expect(userinfo_response[:email]).to eq(user.email)
    expect(userinfo_response[:verified_at]).to eq(profile.verified_at.to_i)
  end

  it 'returns a null verified_at if the account has not been proofed', driver: :mobile_rack_test do
    token_response = sign_in_get_token_response(
      scope: 'openid email profile:verified_at',
      handoff_page_steps: proc do
        expect(page).not_to have_content(t('help_text.requested_attributes.verified_at'))

        click_agree_and_continue
      end,
    )

    access_token = token_response[:access_token]
    expect(access_token).to be_present

    page.driver.get api_openid_connect_userinfo_path,
                    {},
                    'HTTP_AUTHORIZATION' => "Bearer #{access_token}"

    userinfo_response = JSON.parse(page.body).with_indifferent_access
    expect(userinfo_response[:email]).to be_present
    expect(userinfo_response[:verified_at]).to be_nil
  end

  it 'errors if verified_within param is too recent', driver: :mobile_rack_test do
    client_id = 'urn:gov:gsa:openidconnect:test'
    state = SecureRandom.hex
    nonce = SecureRandom.hex
    code_verifier = SecureRandom.hex
    code_challenge = Digest::SHA256.urlsafe_base64digest(code_verifier)

    _user = user_with_2fa

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email profile',
      redirect_uri: 'gov.gsa.openidconnect.test://result',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
      code_challenge: code_challenge,
      code_challenge_method: 'S256',
      verified_within: '1w',
    )

    redirect_params = UriService.params(current_url)

    expect(redirect_params[:error]).to eq('invalid_request')
    expect(redirect_params[:error_description]).
      to include('Verified within value must be at least 30 days or older')
  end

  it 'sends the user through idv again via verified_within param', js: true do
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    user = user_with_2fa
    _profile = create(
      :profile, :active,
      verified_at: 60.days.ago,
      pii: { first_name: 'John', ssn: '111223333', dob: '1970-01-01' },
      user: user
    )

    token_response = sign_in_get_token_response(
      user: user,
      acr_values: Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF,
      client_id: client_id,
      redirect_uri: 'http://localhost:7654/auth/result',
      scope: 'openid email profile',
      verified_within: '30d',
      proofing_steps: proc do
        complete_all_doc_auth_steps_before_password_step
        fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
        click_continue

        acknowledge_and_confirm_personal_key
      end,
      handoff_page_steps: proc do
        expect(page).to have_content(t('help_text.requested_attributes.verified_at'))
        click_agree_and_continue
      end,
    )

    access_token = token_response[:access_token]
    expect(access_token).to be_present

    Capybara.using_driver(:desktop_rack_test) do
      page.driver.get api_openid_connect_userinfo_path,
                      {},
                      'HTTP_AUTHORIZATION' => "Bearer #{access_token}"

      userinfo_response = JSON.parse(page.body).with_indifferent_access
      expect(userinfo_response[:email]).to eq(user.email)
      expect(userinfo_response[:verified_at]).to be > 60.days.ago.to_i
      expect(userinfo_response[:verified_at]).to eq(user.active_profile.verified_at.to_i)
    end
  end

  it 'prompts for consent if last consent time was over a year ago', driver: :mobile_rack_test do
    client_id = 'urn:gov:gsa:openidconnect:test'
    user = user_with_2fa
    link_identity(user, build(:service_provider, issuer: client_id))

    user.identities.last.update(
      last_consented_at: 2.years.ago,
      created_at: 2.years.ago,
    )

    sign_in_get_id_token(
      user: user,
      client_id: client_id,
      handoff_page_steps: proc do
        expect(page).to have_content(t('titles.sign_up.completion_consent_expired_ial1'))
        expect(page).to_not have_content(t('titles.sign_up.completion_new_sp'))

        click_agree_and_continue
      end,
    )
  end

  it 'prompts for consent if consent was revoked/soft deleted', driver: :mobile_rack_test do
    client_id = 'urn:gov:gsa:openidconnect:test'
    user = user_with_2fa
    link_identity(user, build(:service_provider, issuer: client_id))

    user.identities.last.update!(
      last_consented_at: 2.years.ago,
      created_at: 2.years.ago,
      deleted_at: 2.days.ago,
    )

    sign_in_get_id_token(
      user: user,
      client_id: client_id,
      handoff_page_steps: proc do
        expect(page).to have_content(t('titles.sign_up.completion_new_sp'))
        expect(page).to_not have_content(t('titles.sign_up.completion_consent_expired_ial1'))

        click_agree_and_continue
      end,
    )
  end

  context 'with PKCE', driver: :mobile_rack_test do
    it 'succeeds with client authentication via PKCE' do
      client_id = 'urn:gov:gsa:openidconnect:test'
      state = SecureRandom.hex
      nonce = SecureRandom.hex
      code_verifier = SecureRandom.hex
      code_challenge = Digest::SHA256.urlsafe_base64digest(code_verifier)
      user = user_with_2fa

      link_identity(user, build(:service_provider, issuer: client_id))
      user.identities.last.update!(verified_attributes: ['email'])

      visit openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email',
        redirect_uri: 'gov.gsa.openidconnect.test://result',
        state: state,
        prompt: 'select_account',
        nonce: nonce,
        code_challenge: code_challenge,
        code_challenge_method: 'S256',
      )

      _user = sign_in_live_with_2fa(user)
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

    it 'returns the most recent nonce when there are multiple authorize calls' do
      client_id = 'urn:gov:gsa:openidconnect:test'
      user = user_with_2fa
      link_identity(user, build(:service_provider, issuer: client_id))
      user.identities.last.update!(verified_attributes: ['email'])

      state1 = SecureRandom.hex
      nonce1 = SecureRandom.hex
      code_verifier1 = SecureRandom.hex
      code_challenge1 = Digest::SHA256.urlsafe_base64digest(code_verifier1)

      visit openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email',
        redirect_uri: 'gov.gsa.openidconnect.test://result',
        state: state1,
        prompt: 'select_account',
        nonce: nonce1,
        code_challenge: code_challenge1,
        code_challenge_method: 'S256',
      )

      state2 = SecureRandom.hex
      nonce2 = SecureRandom.hex
      code_verifier2 = SecureRandom.hex
      code_challenge2 = Digest::SHA256.urlsafe_base64digest(code_verifier2)

      visit openid_connect_authorize_path(
        client_id: client_id,
        response_type: 'code',
        acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
        scope: 'openid email',
        redirect_uri: 'gov.gsa.openidconnect.test://result',
        state: state2,
        prompt: 'select_account',
        nonce: nonce2,
        code_challenge: code_challenge2,
        code_challenge_method: 'S256',
      )

      sign_in_live_with_2fa(user)
      continue_as(user.email)

      redirect_uri2 = URI(current_url)
      expect(redirect_uri2.to_s).to start_with('gov.gsa.openidconnect.test://result')

      redirect_params2 = Rack::Utils.parse_query(redirect_uri2.query).with_indifferent_access
      aggregate_failures do
        expect(redirect_params2[:state]).to eq(state2)
        expect(redirect_params2[:state]).to_not eq(state1)
      end

      code2 = redirect_params2[:code]
      expect(code2).to be_present

      page.driver.post api_openid_connect_token_path,
                       grant_type: 'authorization_code',
                       code: code2,
                       code_verifier: code_verifier2

      expect(page.status_code).to eq(200)
      token_response2 = JSON.parse(page.body).with_indifferent_access

      id_token2 = token_response2[:id_token]
      expect(id_token2).to be_present
      decoded_id_token2, _headers = JWT.decode(
        id_token2, sp_public_key, true, algorithm: 'RS256'
      ).map(&:with_indifferent_access)

      aggregate_failures do
        expect(decoded_id_token2['nonce']).to eq(nonce2)
        expect(decoded_id_token2['nonce']).to_not eq(nonce1)
      end
    end

    it 'continues to the branded authorization page on first-time signup', email: true do
      client_id = 'urn:gov:gsa:openidconnect:test'
      email = 'test@test.com'

      perform_in_browser(:one) do
        visit openid_connect_authorize_path(
          client_id: client_id,
          response_type: 'code',
          acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
          scope: 'openid email',
          redirect_uri: 'gov.gsa.openidconnect.test://result',
          state: SecureRandom.hex,
          nonce: SecureRandom.hex,
          prompt: 'select_account',
          code_challenge: Digest::SHA256.urlsafe_base64digest(SecureRandom.hex),
          code_challenge_method: 'S256',
        )

        sp_content = [
          'Example iOS App',
          t('headings.create_account_with_sp.sp_text', app_name: APP_NAME),
        ].join(' ')

        expect(page).to have_content(sp_content)

        expect(page).to have_link(
          t('links.back_to_sp', sp: 'Example iOS App'), href: return_to_sp_cancel_path
        )

        sign_up_user_from_sp_without_confirming_email(email)
      end

      perform_in_browser(:two) do
        confirm_email_in_a_different_browser(email)

        click_agree_and_continue
        continue_as(email)
        redirect_uri = URI(current_url)
        expect(redirect_uri.to_s).to start_with('gov.gsa.openidconnect.test://result')
        expect(page.get_rack_session.keys).to include('sp')
      end
    end
  end

  context 'visiting IdP via SP, then going back to SP and visiting IdP again' do
    it 'displays the branded page' do
      visit_idp_from_ial1_oidc_sp

      expect(current_url).to match(%r{http://www.example.com/\?request_id=.+})

      visit_idp_from_ial1_oidc_sp

      expect(current_url).to match(%r{http://www.example.com/\?request_id=.+})
    end
  end

  context 'logging into an SP for the first time' do
    it 'displays shared attributes page once' do
      user = user_with_2fa

      oidc_path = visit_idp_from_ial1_oidc_sp(prompt: 'select_account')
      sign_in_live_with_2fa(user)
      sp = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:server')

      expect(current_url).to eq(sign_up_completed_url)
      expect(page).to have_content(
        t(
          'titles.sign_up.completion_first_sign_in',
          sp: sp.friendly_name,
        ),
      )

      click_agree_and_continue
      expect(current_url).to start_with('http://localhost:7654/auth/result')
      visit sign_out_url
      visit oidc_path
      sign_in_live_with_2fa(user)

      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end

  context 'going back to the SP' do
    it 'links back to the SP from the sign in page' do
      visit_idp_from_ial1_oidc_sp(prompt: 'select_account')

      expect(page).to have_link(
        "‹ #{t('links.back_to_sp', sp: 'Test SP')}", href: return_to_sp_cancel_path
      )
    end
  end

  context 'signing out' do
    it 'redirects back to the client app and destroys the session' do
      id_token = sign_in_get_id_token

      state = SecureRandom.hex

      visit openid_connect_logout_path(
        post_logout_redirect_uri: 'gov.gsa.openidconnect.test://result/signout',
        state: state,
        id_token_hint: id_token,
      )

      visit account_path
      expect(page).to_not have_content(t('headings.account.login_info'))
      expect(page).to have_content(t('headings.sign_in_without_sp'))
    end
  end

  context 'canceling sign in with active identities present' do
    it 'signs the user out and returns to the home page' do
      user = create(:user, :signed_up)

      visit_idp_from_ial1_oidc_sp(prompt: 'select_account')
      fill_in_credentials_and_submit(user.email, user.password)
      uncheck(t('forms.messages.remember_device'))
      fill_in_code_with_last_phone_otp
      click_submit_default
      visit destroy_user_session_url

      visit_idp_from_ial1_oidc_sp(prompt: 'select_account')
      fill_in_credentials_and_submit(user.email, user.password)
      uncheck(t('forms.messages.remember_device'))
      sp_request_id = ServiceProviderRequestProxy.last.uuid
      sp = ServiceProvider.find_by(issuer: 'urn:gov:gsa:openidconnect:sp:server')
      click_link t('links.cancel')

      expect(current_url).to eq new_user_session_url(request_id: sp_request_id)
      expect(page).to have_content t('links.back_to_sp', sp: sp.friendly_name)
    end
  end

  context 'starting account creation on mobile and finishing on desktop' do
    it 'prompts the user to go back to the mobile app', email: true do
      email = 'test@test.com'

      perform_in_browser(:one) do
        visit_idp_from_mobile_app_with_ial1
        sign_up_user_from_sp_without_confirming_email(email)
      end

      perform_in_browser(:two) do
        confirm_email_in_a_different_browser(email)
        click_agree_and_continue

        expect(current_url).to eq new_user_session_url
        expect(page).
          to have_content t('instructions.go_back_to_mobile_app', friendly_name: 'Example iOS App')
      end
    end
  end

  it 'does not make too many queries' do
    queries = QueryTracker.track do
      visit_idp_from_ial1_oidc_sp
    end

    expect(queries[:service_providers].count).to be <= 6
  end

  def visit_idp_from_mobile_app_with_ial1(state: SecureRandom.hex)
    client_id = 'urn:gov:gsa:openidconnect:test'
    nonce = SecureRandom.hex

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'gov.gsa.openidconnect.test://result',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def sign_in_get_id_token(**args)
    token_response = sign_in_get_token_response(**args)
    token_response[:id_token]
  end

  def sign_in_get_token_response(
    user: user_with_2fa,
    acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
    scope: 'openid email',
    redirect_uri: 'gov.gsa.openidconnect.test://result',
    handoff_page_steps: nil,
    proofing_steps: nil,
    verified_within: nil,
    client_id: 'urn:gov:gsa:openidconnect:test'
  )
    state = SecureRandom.hex
    nonce = SecureRandom.hex
    code_verifier = SecureRandom.hex
    code_challenge = Digest::SHA256.urlsafe_base64digest(code_verifier)

    link_identity(user, build(:service_provider, issuer: client_id))
    user.identities.last.update!(verified_attributes: ['email'])

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: acr_values,
      scope: scope,
      redirect_uri: redirect_uri,
      state: state,
      prompt: 'select_account',
      nonce: nonce,
      code_challenge: code_challenge,
      code_challenge_method: 'S256',
      verified_within: verified_within,
    )

    _user = sign_in_live_with_2fa(user)

    proofing_steps&.call
    handoff_page_steps&.call

    redirect_uri = URI(current_url)
    redirect_params = Rack::Utils.parse_query(redirect_uri.query).with_indifferent_access
    code = redirect_params[:code]
    expect(code).to be_present

    Capybara.using_driver(:desktop_rack_test) do
      page.driver.post api_openid_connect_token_path,
                       grant_type: 'authorization_code',
                       code: code,
                       code_verifier: code_verifier
      expect(page.status_code).to eq(200)

      JSON.parse(page.body).with_indifferent_access
    end
  end

  def certs_response
    page.driver.get api_openid_connect_certs_path

    expect(page.status_code).to eq(200)
    JSON.parse(page.body).with_indifferent_access
  end

  def sp_public_key
    JWT::JWK.import(certs_response[:keys].first).public_key
  end

  def client_private_key
    @client_private_key ||= begin
      OpenSSL::PKey::RSA.new(
        File.read(Rails.root.join('keys', 'saml_test_sp.key')),
      )
    end
  end

  def oidc_end_client_secret_jwt(prompt: nil, user: nil, redirs_to: nil)
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    state = SecureRandom.hex
    nonce = SecureRandom.hex

    visit_idp_from_ial2_oidc_sp(prompt: prompt, state: state, nonce: nonce, client_id: client_id)
    continue_as(user.email) if user
    if redirs_to
      expect(current_path).to eq(redirs_to)
      return
    end
    expect(current_path).to eq('/')

    user ||= create(
      :profile, :active, :verified,
      pii: { first_name: 'John', ssn: '111223333' }
    ).user

    sign_in_live_with_2fa(user)
    click_agree_and_continue_optional
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
    expect(decoded_id_token[:acr]).to eq(Saml::Idp::Constants::IAL2_AUTHN_CONTEXT_CLASSREF)
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
    user
  end
end
