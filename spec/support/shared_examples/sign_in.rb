shared_examples 'signing in with the site in Spanish' do |sp|
  it 'redirects to the SP' do
    Capybara.current_session.driver.header('Accept-Language', 'es')

    user = create(:user, :signed_up)
    visit_idp_from_sp_with_ial1(sp)
    fill_in_credentials_and_submit(user.email, user.password)
    continue_as(user.email)

    if sp == :oidc
      expect(page.response_headers['Content-Security-Policy']).
        to(include('form-action \'self\' http://localhost:7654'))
    end

    fill_in_code_with_last_phone_otp
    sp == :saml ? click_submit_default_twice : click_submit_default

    expect(current_url).to eq(sign_up_completed_url(locale: 'es'))

    click_agree_and_continue

    if sp == :saml
      expect(current_url).to eq UriService.add_params(complete_saml_url, locale: 'es')
    elsif sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in as IAL1 with personal key' do |sp|
  it 'redirects to the SP after acknowledging new personal key', email: true do
    ial1_sign_in_with_personal_key_goes_to_sp(sp)
  end
end

shared_examples 'signing in as IAL1 with piv/cac' do |sp|
  it 'redirects to the SP after authenticating', email: true do
    ial1_sign_in_with_piv_cac_goes_to_sp(sp)
  end
end

shared_examples 'visiting 2fa when fully authenticated' do |sp|
  it 'redirects to SP after visiting a 2fa screen when fully authenticated', email: true do
    ial1_sign_in_with_personal_key_goes_to_sp(sp)

    visit login_two_factor_options_path

    click_continue
    continue_as
    expect(current_url).to eq complete_saml_url if sp == :saml

    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in as IAL2 with personal key' do |sp|
  it 'does not present personal key as an MFA option', :email, js: true do
    user = create_ial2_account_go_back_to_sp_and_sign_out(sp)

    Capybara.reset_sessions!

    visit_idp_from_sp_with_ial2(sp)
    fill_in_credentials_and_submit(user.email, user.password)
    click_link t('two_factor_authentication.login_options_link_text')

    expect(page).
      to_not have_selector("label[for='two_factor_options_form_selection_ personal_key']")
  end
end

shared_examples 'signing in as IAL2 with piv/cac' do |sp|
  it 'redirects to the SP after authenticating and getting the password', :email, js: true do
    ial2_sign_in_with_piv_cac_goes_to_sp(sp)
  end

  if sp == :saml
    context 'no authn_context specified' do
      it 'redirects to the SP after authenticating and getting the password', :email, js: true do
        no_authn_context_sign_in_with_piv_cac_goes_to_sp(sp)
      end
    end
  end

  it 'gets bad password error', :email, js: true do
    ial2_sign_in_with_piv_cac_gets_bad_password_error(sp)
  end
end

shared_examples 'signing in as IAL1 with personal key after resetting password' do |sp|
  it 'redirects to SP', email: true do
    user = create_ial1_account_go_back_to_sp_and_sign_out(sp)

    set_new_browser_session

    old_personal_key = PersonalKeyGenerator.new(user).create
    visit_idp_from_sp_with_ial1(sp)
    trigger_reset_password_and_click_email_link(user.confirmed_email_addresses.first.email)
    fill_in t('forms.passwords.edit.labels.password'), with: new_password
    click_button t('forms.passwords.edit.buttons.submit')
    fill_in_credentials_and_submit(user.confirmed_email_addresses.first.email, new_password)
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: old_personal_key)
    click_submit_default
    click_agree_and_continue

    expect(current_url).to eq complete_saml_url if sp == :saml
    if sp == :oidc
      redirect_uri = URI(current_url)

      expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
    end
  end
end

shared_examples 'signing in as IAL2 with personal key after resetting password' do |sp|
  xit 'redirects to SP after reactivating account', :email, js: true do
    user = create_ial2_account_go_back_to_sp_and_sign_out(sp)
    visit_idp_from_sp_with_ial2(sp)
    trigger_reset_password_and_click_email_link(user.email)
    fill_in t('forms.passwords.edit.labels.password'), with: new_password
    click_button t('forms.passwords.edit.buttons.submit')
    fill_in_credentials_and_submit(user.email, new_password)
    choose_another_security_option('personal_key')
    enter_personal_key(personal_key: personal_key_for_ial2_user(user, pii))
    click_submit_default

    expect(current_path).to eq manage_personal_key_path

    new_personal_key = scrape_personal_key
    acknowledge_and_confirm_personal_key

    expect(current_path).to eq reactivate_account_path

    reactivate_profile(new_password, new_personal_key)

    expect(current_path).to eq manage_personal_key_path

    acknowledge_and_confirm_personal_key

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

      visit_idp_from_sp_with_ial1(sp)
      sp_request_id = ServiceProviderRequestProxy.last.uuid
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
      visit_idp_from_sp_with_ial1(sp)
      sp_request_id = ServiceProviderRequestProxy.last.uuid
      fill_in_credentials_and_submit(user.email, 'password')

      link_url = new_user_password_url(locale: 'es', request_id: sp_request_id)
      expect(page).
        to have_link t('devise.failure.invalid_link_text', href: link_url)
    end
  end
end

shared_examples 'signing in as proofed account with broken personal key' do |protocol, sp_ial:|
  let(:window_start) { 3.days.ago }
  let(:window_end) { 1.day.ago }

  before do
    allow(IdentityConfig.store).to receive(:broken_personal_key_window_start).
      and_return(window_start)
    allow(IdentityConfig.store).to receive(:broken_personal_key_window_finish).
      and_return(window_end)
  end

  def user_with_broken_personal_key(protocol, scenario)
    user = create_ial2_account_go_back_to_sp_and_sign_out(protocol)

    case scenario
    when :broken_personal_key_window
      user.active_profile.update(verified_at: window_start + 1.hour)
      user.update(encrypted_recovery_code_digest_generated_at: nil)
    when :encrypted_data_too_short
      personal_key = RandomPhrase.new(num_words: 4).to_s
      user.active_profile.update(
        encrypted_pii_recovery: Encryption::Encryptors::PiiEncryptor.new(personal_key).
          encrypt('null', user_uuid: user.uuid),
      )
    else
      raise "unknown scenario #{scenario}"
    end

    user
  end

  [
    [
      'with a personal key during generated during the broken window',
      :broken_personal_key_window,
    ],
    [
      'with encrypted recovery PII that is too short to be actual data',
      :encrypted_data_too_short,
    ],
  ].each do |description, scenario|
    context description do
      context "protocol: #{protocol}, ial: #{sp_ial}" do
        it 'prompts the user to get a new personal key when using email/password', js: true do
          user = user_with_broken_personal_key(protocol, scenario)

          case sp_ial
          when 1
            visit_idp_from_sp_with_ial2(protocol)
          when 2
            visit_idp_from_sp_with_ial1(protocol)
          else
            raise "unknown sp_ial=#{sp_ial}"
          end

          fill_in_credentials_and_submit(user.email, user.password)

          expect(page).to have_content(t('account.personal_key.needs_new'))
          code = page.all('.separator-text__code').map(&:text).join(' ')
          acknowledge_and_confirm_personal_key

          expect(user.reload.valid_personal_key?(code)).to eq(true)
          expect(user.active_profile.reload.recover_pii(code)).to be_present
        end

        it 'prompts for password when signing in via PIV/CAC', js: true do
          user = user_with_broken_personal_key(protocol, scenario)

          create(:piv_cac_configuration, user: user)

          visit_idp_from_sp_with_ial1(protocol)
          click_on t('account.login.piv_cac')
          fill_in_piv_cac_credentials_and_submit(user)
          click_submit_default if protocol == :saml

          expect(page).to have_content(t('account.personal_key.needs_new'))
          expect(page).to have_content(t('headings.passwords.confirm_for_personal_key'))

          fill_in t('forms.password'), with: user.password
          click_button t('forms.buttons.submit.default')

          expect(page).to have_content(t('account.personal_key.needs_new'))
          code = page.all('.separator-text__code').map(&:text).join(' ')
          acknowledge_and_confirm_personal_key

          expect(user.reload.valid_personal_key?(code)).to eq(true)
          expect(user.active_profile.reload.recover_pii(code)).to be_present
        end
      end
    end
  end
end

def personal_key_for_ial2_user(user, pii)
  pii_attrs = Pii::Attributes.new_from_hash(pii)
  profile = user.profiles.last
  personal_key = profile.encrypt_pii(pii_attrs, user.password)
  profile.save!

  personal_key
end

def ial1_sign_in_with_personal_key_goes_to_sp(sp)
  user = create_ial1_account_go_back_to_sp_and_sign_out(sp)
  old_personal_key = PersonalKeyGenerator.new(user).create

  Capybara.reset_sessions!

  visit_idp_from_sp_with_ial1(sp)
  fill_in_credentials_and_submit(user.confirmed_email_addresses.first.email, 'Val!d Pass w0rd')
  choose_another_security_option('personal_key')
  enter_personal_key(personal_key: old_personal_key)
  click_submit_default
  click_agree_and_continue

  expect(current_url).to eq complete_saml_url if sp == :saml

  return unless sp == :oidc

  redirect_uri = URI(current_url)

  expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
end

def ial1_sign_in_with_piv_cac_goes_to_sp(sp)
  user = create_ial1_account_go_back_to_sp_and_sign_out(sp)
  user.piv_cac_configurations.create(x509_dn_uuid: 'some-uuid-to-identify-account', name: 'foo')
  visit_idp_from_sp_with_ial1(sp)

  click_on t('account.login.piv_cac')
  fill_in_piv_cac_credentials_and_submit(user)
  click_submit_default if sp == :saml
  click_agree_and_continue
  return unless sp == :oidc
  redirect_uri = URI(current_url)

  expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
end

def ial2_sign_in_with_piv_cac_goes_to_sp(sp)
  user = create_ial2_account_go_back_to_sp_and_sign_out(sp)
  user.piv_cac_configurations.create(x509_dn_uuid: 'some-uuid-to-identify-account', name: 'foo')

  visit_idp_from_sp_with_ial2(sp)

  click_on t('account.login.piv_cac')
  fill_in_piv_cac_credentials_and_submit(user)

  # capture password before redirecting to SP
  expect(current_url).to eq capture_password_url

  fill_in_password_and_submit(user.password)

  if sp == :saml
    if javascript_enabled?
      expect(current_path).to eq(test_saml_decode_assertion_path)
    else
      expect(current_url).to include(@saml_authn_request)
    end
  elsif sp == :oidc
    redirect_uri = URI(current_url)

    expect(redirect_uri.to_s).to start_with('http://localhost:7654/auth/result')
  end
end

def no_authn_context_sign_in_with_piv_cac_goes_to_sp(sp)
  raise NotImplementedError if sp == :oidc

  user = create_ial2_account_go_back_to_sp_and_sign_out(sp)
  user.piv_cac_configurations.create(x509_dn_uuid: 'some-uuid-to-identify-account', name: 'foo')

  visit_saml_authn_request_url(
    overrides: {
      issuer: sp1_issuer,
      authn_context: nil,
    },
  )

  click_on t('account.login.piv_cac')
  fill_in_piv_cac_credentials_and_submit(user)

  # capture password before redirecting to SP
  expect(current_url).to eq capture_password_url

  fill_in_password_and_submit(user.password)

  # needed because the SP default attribute bundle includes the zip_code
  # attribute which wasn't originally requested, so consent is required
  expect(page).to have_current_path(sign_up_completed_path)
  click_agree_and_continue

  if javascript_enabled?
    expect(current_path).to eq(test_saml_decode_assertion_path)
  else
    expect(current_url).to eq @saml_authn_request
  end
end

def ial2_sign_in_with_piv_cac_gets_bad_password_error(sp)
  user = create_ial2_account_go_back_to_sp_and_sign_out(sp)
  user.piv_cac_configurations.create(x509_dn_uuid: 'some-uuid-to-identify-account', name: 'foo')

  visit_idp_from_sp_with_ial2(sp)

  click_on t('account.login.piv_cac')
  fill_in_piv_cac_credentials_and_submit(user)

  expect(current_url).to eq capture_password_url

  max_allowed_attempts = IdentityConfig.store.password_max_attempts
  (max_allowed_attempts - 1).times do
    fill_in t('account.index.password'), with: 'badpassword'
    click_button t('forms.buttons.submit.default')
    expect(page).to have_content(t('errors.confirm_password_incorrect'))
  end

  fill_in t('account.index.password'), with: 'badpassword'
  click_button t('forms.buttons.submit.default')
  expect(page).to have_content(t('errors.max_password_attempts_reached'))
end
