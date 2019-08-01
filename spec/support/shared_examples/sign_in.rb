shared_examples 'signing in with the site in Spanish' do |sp|
  it 'redirects to the SP' do
    Capybara.current_session.driver.header('Accept-Language', 'es')

    user = create(:user, :signed_up)
    visit_idp_from_sp_with_loa1(sp)
    fill_in_credentials_and_submit(user.email, user.password)

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    fill_in_code_with_last_phone_otp
    click_submit_default

    expect(current_url).to eq(sign_up_completed_url(locale: 'es'))

    click_continue

    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in as LOA1 with personal key' do |sp|
  it 'redirects to the SP after acknowledging new personal key', email: true do
    loa1_sign_in_with_personal_key_goes_to_sp(sp)
  end
end

shared_examples 'signing in as LOA1 with piv/cac' do |sp|
  it 'redirects to the SP after authenticating', email: true do
    loa1_sign_in_with_piv_cac_goes_to_sp(sp)
  end
end

shared_examples 'visiting 2fa when fully authenticated' do |sp|
  before { Timecop.freeze Time.zone.now }
  after { Timecop.return }

  it 'redirects to SP after visiting a 2fa screen when fully authenticated', email: true do
    loa1_sign_in_with_personal_key_goes_to_sp(sp)

    visit login_two_factor_options_path

    click_continue
    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in as LOA3 with personal key' do |sp|
  before { Timecop.freeze Time.zone.now }
  after { Timecop.return }

  it 'redirects to the SP after acknowledging new personal key', :email do
    user = create_loa3_account_go_back_to_sp_and_sign_out(sp)
    pii = { ssn: '666-66-1234', dob: '1920-01-01', first_name: 'alice' }

    visit_idp_from_sp_with_loa3(sp)
    fill_in_credentials_and_submit(user.email, user.password)
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: personal_key_for_loa3_user(user, pii))
    click_submit_default

    expect(page).to have_current_path(manage_personal_key_path)

    click_acknowledge_personal_key

    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in as LOA3 with piv/cac' do |sp|
  it 'redirects to the SP after authenticating and getting the password', :email do
    loa3_sign_in_with_piv_cac_goes_to_sp(sp)
  end

  it 'gets bad password error', :email do
    loa3_sign_in_with_piv_cac_gets_bad_password_error(sp)
  end
end

shared_examples 'signing in as LOA1 with personal key after resetting password' do |sp|
  before { Timecop.freeze Time.zone.now }
  after { Timecop.return }

  it 'redirects to SP', email: true do
    user = create_loa1_account_go_back_to_sp_and_sign_out(sp)
    old_personal_key = PersonalKeyGenerator.new(user).create
    visit_idp_from_sp_with_loa1(sp)
    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, new_password)
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: old_personal_key)
    click_submit_default
    click_continue

    expect(current_url).to eq @saml_authn_request if sp == :saml
    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in as LOA3 with personal key after resetting password' do |sp|
  xit 'redirects to SP after reactivating account', :email do
    user = create_loa3_account_go_back_to_sp_and_sign_out(sp)
    visit_idp_from_sp_with_loa3(sp)
    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, new_password)
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: personal_key_for_loa3_user(user, pii))
    click_submit_default

    expect(current_path).to eq manage_personal_key_path

    new_personal_key = scrape_personal_key
    click_acknowledge_personal_key

    expect(current_path).to eq reactivate_account_path

    reactivate_profile(new_password, new_personal_key)

    expect(current_path).to eq manage_personal_key_path

    click_acknowledge_personal_key

    expect(current_url).to eq @saml_authn_request if sp == :saml
    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in with wrong credentials' do |sp|
  # This tests the custom Devise error message defined in lib/custom_devise_failure_app.rb
  context 'when the user does not exist' do
    it 'links to forgot password page with locale and request_id' do
      Capybara.current_session.driver.header('Accept-Language', 'es')

      visit_idp_from_sp_with_loa1(sp)
      sp_request_id = ServiceProviderRequest.last.uuid
      fill_in_credentials_and_submit('test@test.com', 'foo')

      link_url = new_user_password_url(locale: 'es', request_id: sp_request_id)
      expect(page).
        to have_link t('devise.failure.not_found_in_database_link_text', href: link_url)
    end
  end

  context 'when the user exists' do
    it 'links to forgot password page with locale and request_id' do
      Capybara.current_session.driver.header('Accept-Language', 'es')

      user = create(:user, :signed_up)
      visit_idp_from_sp_with_loa1(sp)
      sp_request_id = ServiceProviderRequest.last.uuid
      fill_in_credentials_and_submit(user.email, 'password')

      link_url = new_user_password_url(locale: 'es', request_id: sp_request_id)
      expect(page).
        to have_link t('devise.failure.invalid_link_text', href: link_url)
    end
  end
end

shared_examples 'signing with while PIV/CAC enabled but no other second factor' do |sp|
  it 'does not allow bypassing setting up backup factor' do
    stub_piv_cac_service

    user = create(:user, :with_piv_or_cac)
    MfaContext.new(user).phone_configurations.clear
    visit_idp_from_sp_with_loa1(sp)
    fill_in_credentials_and_submit(user.email, user.password)
    nonce = visit_login_two_factor_piv_cac_and_get_nonce

    visit_piv_cac_service(login_two_factor_piv_cac_path,
                          uuid: user.x509_dn_uuid,
                          dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
                          nonce: nonce)

    expect(current_path).to eq two_factor_options_success_path

    visit_idp_from_sp_with_loa1(sp)

    expect(current_path).to eq two_factor_options_path
  end

  it 'does allow bypassing setting up backup factor if there is a factor other than phone' do
    stub_piv_cac_service

    user = create(:user, :with_piv_or_cac, :with_authentication_app)
    MfaContext.new(user).phone_configurations.clear
    visit_idp_from_sp_with_loa1(sp)
    fill_in_credentials_and_submit(user.email, user.password)
    nonce = visit_login_two_factor_piv_cac_and_get_nonce
    visit_piv_cac_service(login_two_factor_piv_cac_path,
                          uuid: user.x509_dn_uuid,
                          dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
                          nonce: nonce)

    expect(page).to have_current_path(sign_up_completed_path)
  end
end

def personal_key_for_loa3_user(user, pii)
  pii_attrs = Pii::Attributes.new_from_hash(pii)
  profile = user.profiles.last
  personal_key = profile.encrypt_pii(pii_attrs, user.password)
  profile.save!

  personal_key
end

def loa1_sign_in_with_personal_key_goes_to_sp(sp)
  Timecop.freeze Time.zone.now do
    user = create_loa1_account_go_back_to_sp_and_sign_out(sp)
    old_personal_key = PersonalKeyGenerator.new(user).create
    visit_idp_from_sp_with_loa1(sp)
    fill_in_credentials_and_submit(user.email, 'Val!d Pass w0rd')
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: old_personal_key)
    click_submit_default
    click_continue

    expect(current_url).to eq @saml_authn_request if sp == :saml

    return unless sp == :oidc

    redirect_uri = URI(current_url)

    expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
  end
end

def loa1_sign_in_with_piv_cac_goes_to_sp(sp)
  user = create_loa1_account_go_back_to_sp_and_sign_out(sp)
  user.update!(x509_dn_uuid: 'some-uuid-to-identify-account')
  visit_idp_from_sp_with_loa1(sp)

  click_on t('account.login.piv_cac')
  fill_in_piv_cac_credentials_and_submit(user)

  click_continue
  return unless sp == :oidc
  redirect_uri = URI(current_url)

  expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
end

def loa3_sign_in_with_piv_cac_goes_to_sp(sp)
  user = create_loa3_account_go_back_to_sp_and_sign_out(sp)
  user.update!(x509_dn_uuid: 'some-uuid-to-identify-account')

  visit_idp_from_sp_with_loa3(sp)

  click_on t('account.login.piv_cac')
  fill_in_piv_cac_credentials_and_submit(user)

  # capture password before redirecting to SP
  expect(current_url).to eq capture_password_url

  if sp == :oidc
    expect(page.response_headers['Content-Security-Policy']).
      to(include('form-action \'self\' http://localhost:7654'))
  end

  fill_in_password_and_submit(user.password)

  if sp == :saml
    expect(current_url).to eq @saml_authn_request
  elsif sp == :oidc
    redirect_uri = URI(current_url)

    expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
  end
end

def loa3_sign_in_with_piv_cac_gets_bad_password_error(sp)
  user = create_loa3_account_go_back_to_sp_and_sign_out(sp)
  user.update!(x509_dn_uuid: 'some-uuid-to-identify-account')

  visit_idp_from_sp_with_loa3(sp)

  click_on t('account.login.piv_cac')
  fill_in_piv_cac_credentials_and_submit(user)

  expect(current_url).to eq capture_password_url

  max_allowed_attempts = Figaro.env.password_max_attempts.to_i
  (max_allowed_attempts - 1).times do
    fill_in 'user_password', with: 'badpassword'
    click_button t('links.next')
    expect(page).to have_content(t('errors.confirm_password_incorrect'))
  end

  fill_in 'user_password', with: 'badpassword'
  click_button t('links.next')
  expect(page).to have_content(t('errors.max_password_attempts_reached'))
end
