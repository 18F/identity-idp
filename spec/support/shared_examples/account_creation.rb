shared_examples 'creating an account with the site in Spanish' do |sp|
  it 'redirects to the SP', email: true do
    Capybara.current_session.driver.header('Accept-Language', 'es')
    visit_idp_from_sp_with_ial1(sp)
    register_user

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_submit_default if sp == :saml
    click_agree_and_continue
    if :sp == :saml
      expect(current_url).to eq UriService.add_params(@saml_authn_request, locale: :es)
    elsif sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'creating an account using authenticator app for 2FA' do |sp|
  it 'redirects to the SP', email: true do
    visit_idp_from_sp_with_ial1(sp)
    register_user_with_authenticator_app

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    click_agree_and_continue
    expect(current_url).to eq complete_saml_url if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'creating an IAL2 account using authenticator app for 2FA' do |sp|
  it 'does not prompt for recovery code before IdV flow', email: true, idv_job: true, js: true do
    visit_idp_from_sp_with_ial2(sp)
    register_user_with_authenticator_app
    expect(page).to have_current_path(idv_doc_auth_step_path(step: :welcome))
    complete_all_doc_auth_steps
    fill_out_phone_form_ok
    choose_idv_otp_delivery_method_sms
    fill_in_code_with_last_phone_otp
    click_submit_default
    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_continue
    acknowledge_and_confirm_personal_key

    click_agree_and_continue
    expect(current_path).to eq test_saml_decode_assertion_path if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'creating an account using PIV/CAC for 2FA' do |sp|
  it 'redirects to the SP', email: true do
    visit_idp_from_sp_with_ial1(sp)
    register_user_with_piv_cac

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end
    click_submit_default if sp == :saml

    click_agree_and_continue
    expect(current_url).to eq complete_saml_url if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'creating an IAL2 account using webauthn for 2FA' do |sp|
  it 'does not prompt for recovery code before IdV flow', email: true, js: true do
    mock_webauthn_setup_challenge
    visit_idp_from_sp_with_ial2(sp)
    confirm_email_and_password('test@test.com')
    select_2fa_option('webauthn', visible: :all)
    fill_in_nickname_and_click_continue
    mock_press_button_on_hardware_key_on_setup
    skip_second_mfa_prompt
    expect(page).to have_current_path(idv_doc_auth_step_path(step: :welcome))
    complete_all_doc_auth_steps
    fill_out_phone_form_ok
    choose_idv_otp_delivery_method_sms
    fill_in_code_with_last_phone_otp
    click_submit_default
    fill_in 'Password', with: Features::SessionHelper::VALID_PASSWORD
    click_continue
    acknowledge_and_confirm_personal_key

    click_agree_and_continue
    expect(current_path).to eq test_saml_decode_assertion_path if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'creating two accounts during the same session' do |sp|
  it 'allows the second account creation process to complete fully', email: true do
    first_email = 'test1@test.com'
    second_email = 'test2@test.com'

    perform_in_browser(:one) do
      visit_idp_from_sp_with_ial1(sp)
      sign_up_user_from_sp_without_confirming_email(first_email)
    end

    perform_in_browser(:two) do
      confirm_email_in_a_different_browser(first_email)
      click_submit_default if sp == :saml
      click_agree_and_continue

      continue_as(first_email)

      expect(current_url).to eq complete_saml_url if sp == :saml
      if sp == :oidc
        redirect_uri = URI(current_url)

        expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
      end
      expect(page.get_rack_session.keys).to include('sp')
    end

    perform_in_browser(:one) do
      visit_idp_from_sp_with_ial1(sp)
      sign_up_user_from_sp_without_confirming_email(second_email)
    end

    perform_in_browser(:two) do
      Capybara.reset_session!
      confirm_email_in_a_different_browser(second_email)
      click_submit_default if sp == :saml
      click_agree_and_continue

      continue_as(second_email)

      expect(current_url).to eq complete_saml_url if sp == :saml
      if sp == :oidc
        redirect_uri = URI(current_url)

        expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
      end
      expect(page.get_rack_session.keys).to include('sp')
    end
  end
end
