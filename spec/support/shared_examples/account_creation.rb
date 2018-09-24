shared_examples 'csrf error when asking for new personal key' do |sp|
  it 'redirects to sign in page', email: true do
    visit_idp_from_sp_with_loa1(sp)
    register_user
    allow_any_instance_of(Users::PersonalKeysController).
      to receive(:create).and_raise(ActionController::InvalidAuthenticityToken)
    click_on t('users.personal_key.get_another')

    expect(current_path).to eq new_user_session_path
    expect(page).to have_content t('errors.invalid_authenticity_token')
  end
end

shared_examples 'csrf error when acknowledging personal key' do |sp|
  it 'redirects to sign in page', email: true do
    visit_idp_from_sp_with_loa1(sp)
    register_user
    allow_any_instance_of(SignUp::PersonalKeysController).
      to receive(:update).and_raise(ActionController::InvalidAuthenticityToken)
    click_acknowledge_personal_key

    expect(current_path).to eq new_user_session_path
    expect(page).to have_content t('errors.invalid_authenticity_token')
  end
end

shared_examples 'creating an account with the site in Spanish' do |sp|
  it 'redirects to the SP', email: true do
    Capybara.current_session.driver.header('Accept-Language', 'es')
    visit_idp_from_sp_with_loa1(sp)
    register_user
    click_acknowledge_personal_key

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_on t('forms.buttons.continue')
    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'creating an account using authenticator app for 2FA' do |sp|
  it 'redirects to the SP', email: true do
    visit_idp_from_sp_with_loa1(sp)
    register_user_with_authenticator_app
    click_acknowledge_personal_key

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_on t('forms.buttons.continue')
    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'creating an LOA3 account using authenticator app for 2FA' do |sp|
  it 'does not prompt for recovery code before IdV flow', email: true, idv_job: true do
    visit_idp_from_sp_with_loa3(sp)
    register_user_with_authenticator_app
    fill_out_idv_jurisdiction_ok
    click_idv_continue
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_continue
    fill_out_phone_form_ok
    click_idv_continue
    choose_idv_otp_delivery_method_sms
    click_submit_default
    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_continue
    click_acknowledge_personal_key

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_on t('forms.buttons.continue')
    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'creating an account using PIV/CAC for 2FA' do |sp|
  it 'redirects to the SP', email: true do
    allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
    visit_idp_from_sp_with_loa1(sp)
    register_user_with_piv_cac

    expect(page).to have_current_path(account_recovery_setup_path)
    expect(page).to have_content t('instructions.account_recovery_setup.piv_cac_next_step')

    select_2fa_option('sms')
    click_link t('two_factor_authentication.choose_another_option')

    expect(page).to have_current_path account_recovery_setup_path

    configure_backup_phone
    click_acknowledge_personal_key

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_on t('forms.buttons.continue')
    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'creating an LOA3 account using webauthn for 2FA' do |sp|
  it 'does not have webauthn as an option', email: true do
    mock_challenge
    visit_idp_from_sp_with_loa3(sp)
    confirm_email_and_password('test@test.com')
    expect(page).to_not have_css("label[for='two_factor_options_form_selection_webauthn']")
  end

  # Remove the above test and enable this one when we enable webauthn for the SPs
  xit 'does not prompt for recovery code before IdV flow', email: true do
    mock_challenge
    visit_idp_from_sp_with_loa3(sp)
    confirm_email_and_password('test@test.com')
    select_2fa_option('webauthn')
    mock_press_button_on_hardware_key_and_fill_in_name_field
    click_submit_default
    fill_out_idv_jurisdiction_ok
    click_idv_continue
    fill_out_idv_form_ok
    click_idv_continue
    click_idv_continue
    fill_out_phone_form_ok
    click_idv_continue
    choose_idv_otp_delivery_method_sms
    click_submit_default
    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_continue
    click_acknowledge_personal_key

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_on t('forms.buttons.continue')
    expect(current_url).to eq @saml_authn_request if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end
