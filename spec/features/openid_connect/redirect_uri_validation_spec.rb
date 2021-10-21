require 'rails_helper'

describe 'redirect_uri validation' do
  context 'when the redirect_uri in the request does not match one that is registered' do
    it 'displays error instead of branded landing page' do
      visit_idp_from_sp_with_ial1_with_disallowed_redirect_uri
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.redirect_uri_no_match')
    end
  end

  context 'when the redirect_uri is not a valid URI' do
    it 'displays error instead of branded landing page' do
      visit_idp_from_sp_with_ial1_with_invalid_redirect_uri
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.redirect_uri_invalid')
    end
  end

  context 'when the service_provider is not active' do
    it 'displays error instead of branded landing page' do
      visit_idp_from_inactive_sp
      current_host = URI.parse(page.current_url).host
      current_path = URI.parse(page.current_url).path

      expect(current_host).to eq 'www.example.com'
      expect(current_path).to eq '/errors/service_provider_inactive'
      expect(page).
        to have_content t(
          'service_providers.errors.inactive.heading',
          sp_name: 'Example iOS App (inactive)',
          app_name: APP_NAME,
        )
    end
  end

  context 'when the service_provider is not real' do
    it 'displays error instead of branded landing page' do
      visit_idp_from_nonexistent_sp
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.bad_client_id')
    end
  end

  context 'when redirect_uri is present in params but the request is not from an SP' do
    it 'does not provide a link to the redirect_uri' do
      visit new_user_session_path(request_id: '123', redirect_uri: 'evil.com')

      expect(page).to_not have_link t('links.back_to_sp')

      visit new_user_session_path(request_id: '123', redirect_uri: 'evil.com')

      expect(page).to_not have_link t('links.back_to_sp')
    end
  end

  context 'when new non-SP request with redirect_uri is made after initial SP request' do
    it 'does not provide a link to the new redirect_uri' do
      state = SecureRandom.hex
      visit_idp_from_sp_with_ial1_with_valid_redirect_uri(state: state)
      visit new_user_session_path(request_id: '123', redirect_uri: 'evil.com')
      sp_redirect_uri = "http://localhost:7654/auth/result?error=access_denied&state=#{state}"

      click_on t('links.back_to_sp', sp: 'Test SP')
      expect(current_url).to eq(sp_redirect_uri)

      visit new_user_session_path(request_id: '123', redirect_uri: 'evil.com')

      click_on t('links.back_to_sp', sp: 'Test SP')
      expect(current_url).to eq(sp_redirect_uri)
    end
  end

  context 'when the user is already signed in directly' do
    it 'displays error instead of redirecting' do
      sign_in_and_2fa_user

      visit_idp_from_nonexistent_sp
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.bad_client_id')

      visit_idp_from_sp_with_ial1_with_invalid_redirect_uri
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.redirect_uri_invalid')

      visit_idp_from_sp_with_ial1_with_disallowed_redirect_uri
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.redirect_uri_no_match')
    end
  end

  context 'when the user is already signed in via an SP' do
    it 'displays error instead of redirecting' do
      user = create(:user, :signed_up)
      visit_idp_from_sp_with_ial1_with_valid_redirect_uri
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_continue

      visit_idp_from_nonexistent_sp
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.bad_client_id')

      visit_idp_from_sp_with_ial1_with_invalid_redirect_uri
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.redirect_uri_invalid')

      visit_idp_from_sp_with_ial1_with_disallowed_redirect_uri
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.redirect_uri_no_match')
    end
  end

  context 'when the SP has multiple registered redirect_uris and the second one is requested' do
    it 'considers the request valid and redirects to the one requested' do
      user = create(:user, :signed_up)
      visit_idp_from_sp_with_ial1_with_second_valid_redirect_uri
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_agree_and_continue

      redirect_host = URI.parse(current_url).host
      redirect_scheme = URI.parse(current_url).scheme

      expect(redirect_host).to eq('example.com')
      expect(redirect_scheme).to eq('https')
    end
  end

  context 'when the SP does not have any registered redirect_uris' do
    it 'considers the request invalid and does not redirect if the user signs in' do
      user = create(:user, :signed_up)
      visit_idp_from_sp_that_does_not_have_redirect_uris
      current_host = URI.parse(page.current_url).host

      expect(current_host).to eq 'www.example.com'
      expect(page).
        to have_content t('openid_connect.authorization.errors.redirect_uri_no_match')

      visit new_user_session_path
      fill_in_credentials_and_submit(user.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
      click_continue

      expect(page).to have_current_path account_path
    end
  end

  def visit_idp_from_sp_with_ial1_with_disallowed_redirect_uri(state: SecureRandom.hex)
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    nonce = SecureRandom.hex

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'https://example.com.evil.com/auth/result',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def visit_idp_from_sp_with_ial1_with_invalid_redirect_uri(state: SecureRandom.hex)
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    nonce = SecureRandom.hex

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: ':aaaa',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def visit_idp_from_nonexistent_sp(state: SecureRandom.hex)
    client_id = 'nonexistent:sp'
    nonce = SecureRandom.hex

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def visit_idp_from_inactive_sp(state: SecureRandom.hex)
    client_id = 'urn:gov:gsa:openidconnect:inactive:sp:test'
    nonce = SecureRandom.hex

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid profile',
      redirect_uri: 'gov.gsa.openidconnect.test://result',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def visit_idp_from_sp_with_ial1_with_valid_redirect_uri(state: SecureRandom.hex)
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    nonce = SecureRandom.hex

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://localhost:7654/auth/result',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def visit_idp_from_sp_with_ial1_with_second_valid_redirect_uri(state: SecureRandom.hex)
    client_id = 'urn:gov:gsa:openidconnect:sp:server'
    nonce = SecureRandom.hex

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'https://example.com',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end

  def visit_idp_from_sp_that_does_not_have_redirect_uris(state: SecureRandom.hex)
    client_id = 'http://test.host'
    nonce = SecureRandom.hex

    visit openid_connect_authorize_path(
      client_id: client_id,
      response_type: 'code',
      acr_values: Saml::Idp::Constants::IAL1_AUTHN_CONTEXT_CLASSREF,
      scope: 'openid email',
      redirect_uri: 'http://test.host',
      state: state,
      prompt: 'select_account',
      nonce: nonce,
    )
  end
end
