shared_examples 'signing in with the site in Spanish' do |sp|
  it 'redirects to the SP' do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    Capybara.current_session.driver.header('Accept-Language', 'es')

    user = create(:user, :signed_up)
    visit_idp_from_sp_with_loa1(sp)
    click_link t('links.sign_in')
    fill_in_credentials_and_submit(user.email, user.password)

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

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
    user = create_loa1_account_go_back_to_sp_and_sign_out(sp)
    old_personal_key = PersonalKeyGenerator.new(user).create
    visit_idp_from_sp_with_loa1(sp)
    click_link t('links.sign_in')
    fill_in_credentials_and_submit(user.email, 'Val!d Pass w0rd')
    click_link t('devise.two_factor_authentication.personal_key_fallback.link')
    enter_personal_key(personal_key: old_personal_key)
    click_submit_default

    expect(page).to have_current_path(manage_personal_key_path)
    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_acknowledge_personal_key

    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in as LOA3 with personal key' do |sp|
  it 'redirects to the SP after acknowledging new personal key', :email, :idv_job do
    user = create_loa3_account_go_back_to_sp_and_sign_out(sp)
    pii = { ssn: '666-66-1234', dob: '1920-01-01', first_name: 'alice' }

    visit_idp_from_sp_with_loa3(sp)
    click_link t('links.sign_in')
    fill_in_credentials_and_submit(user.email, user.password)
    click_link t('devise.two_factor_authentication.personal_key_fallback.link')
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

shared_examples 'signing in as LOA1 with personal key after resetting password' do |sp|
  it 'redirects to SP', email: true do
    user = create_loa1_account_go_back_to_sp_and_sign_out(sp)
    old_personal_key = PersonalKeyGenerator.new(user).create
    visit_idp_from_sp_with_loa1(sp)
    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, new_password)
    click_link t('devise.two_factor_authentication.personal_key_fallback.link')
    enter_personal_key(personal_key: old_personal_key)
    click_submit_default

    expect(current_path).to eq manage_personal_key_path
    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_acknowledge_personal_key

    expect(current_url).to eq @saml_authn_request if sp == :saml
    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in as LOA3 with personal key after resetting password' do |sp|
  xit 'redirects to SP after reactivating account', :email, :idv_job do
    user = create_loa3_account_go_back_to_sp_and_sign_out(sp)
    visit_idp_from_sp_with_loa3(sp)
    trigger_reset_password_and_click_email_link(user.email)
    reset_password_and_sign_back_in(user, new_password)
    click_link t('devise.two_factor_authentication.personal_key_fallback.link')
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
      click_link t('links.sign_in')
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
      click_link t('links.sign_in')
      fill_in_credentials_and_submit(user.email, 'password')

      link_url = new_user_password_url(locale: 'es', request_id: sp_request_id)
      expect(page).
        to have_link t('devise.failure.invalid_link_text', href: link_url)
    end
  end
end

def personal_key_for_loa3_user(user, pii)
  pii_attrs = Pii::Attributes.new_from_hash(pii)
  profile = user.profiles.last
  personal_key = profile.encrypt_pii(pii_attrs, user.password)
  profile.save!

  personal_key
end
