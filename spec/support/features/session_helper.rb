require 'cgi'

module Features
  module SessionHelper
    include JavascriptDriverHelper
    include PersonalKeyHelper

    VALID_PASSWORD = 'Val!d Pass w0rd'.freeze

    IAL1_USER_PHONE = '202-555-1212'.freeze

    def sign_up_with(email)
      visit sign_up_email_path
      check t('sign_up.terms', app_name: APP_NAME)
      fill_in t('forms.registration.labels.email'), with: email
      click_button t('forms.buttons.submit.default')
    end

    def choose_another_security_option(option)
      accept_rules_of_use_and_continue_if_displayed

      click_link t('two_factor_authentication.login_options_link_text')

      expect(current_path).to eq login_two_factor_options_path

      select_2fa_option(option)
    end

    def select_2fa_option(option, **find_options)
      find("label[for='two_factor_options_form_selection_#{option}']", **find_options).click
      click_on t('forms.buttons.continue')
      click_button t('forms.buttons.continue') if page.has_button?(t('forms.buttons.continue'))
    end

    def select_phone_delivery_option(delivery_option)
      choose "new_phone_form_otp_delivery_preference_#{delivery_option}"
    end

    def sign_up_and_2fa_ial1_user
      user = sign_up_and_set_password
      select_2fa_option('phone')
      fill_in 'new_phone_form_phone', with: IAL1_USER_PHONE
      click_send_one_time_code
      uncheck(t('forms.messages.remember_device'))
      fill_in_code_with_last_phone_otp
      click_submit_default
      skip_second_mfa_prompt
      user
    end

    def signin(email, password)
      allow(UserMailer).to receive(:new_device_sign_in).and_call_original
      visit new_user_session_path
      set_hidden_field('platform_authenticator_available', 'true')
      fill_in_credentials_and_submit(email, password)
      continue_as(email, password)
    end

    def signin_with_piv(user = user_with_piv_cac)
      allow(UserMailer).to receive(:new_device_sign_in).and_call_original
      visit new_user_session_path
      click_on t('account.login.piv_cac')
      fill_in_piv_cac_credentials_and_submit(user)
    end

    def signin_with_piv_error(error)
      user = user_with_piv_cac
      visit new_user_session_path
      click_on t('account.login.piv_cac')

      allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?).and_return(false)

      stub_piv_cac_service
      nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_login.submit')))
      visit_piv_cac_service(
        current_url,
        nonce: nonce,
        uuid: user.piv_cac_configurations.first.x509_dn_uuid,
        subject: 'SomeIgnoredSubject',
        error: error,
      )
    end

    def signin_with_bad_piv
      allow(UserMailer).to receive(:new_device_sign_in).and_call_original
      visit new_user_session_path
      click_on t('account.login.piv_cac')
      fill_in_bad_piv_cac_credentials_and_submit
    end

    def fill_in_piv_cac_credentials_and_submit(user,
                                               uuid = user.
                                                 piv_cac_configurations&.first&.x509_dn_uuid)
      allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?).and_return(false)

      stub_piv_cac_service
      nonce = get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_login.submit')))
      visit_piv_cac_service(
        current_url,
        nonce: nonce,
        uuid: uuid,
        subject: 'SomeIgnoredSubject',
      )
    end

    def fill_in_bad_piv_cac_credentials_and_submit
      allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?).and_return(false)

      stub_piv_cac_service
      visit(current_url + '?token=foo')
    end

    def fill_in_credentials_and_submit(email, password)
      fill_in t('account.index.email'), with: email
      fill_in t('account.index.password'), with: password
      click_button t('links.sign_in')
    end

    def fill_in_totp_name(nickname = 'App')
      fill_in 'name', with: nickname
    end

    def continue_as(email = nil, password = VALID_PASSWORD)
      return unless current_url.include?(user_authorization_confirmation_path)

      if email.nil? || page.has_content?(email)
        click_button t('user_authorization_confirmation.continue')
      else
        click_button t('user_authorization_confirmation.sign_in')
        signin(email, password)
      end
    end

    def fill_in_password_and_submit(password)
      fill_in t('account.index.password'), with: password
      click_button t('forms.buttons.submit.default')
    end

    def sign_up
      user = create(:user, :unconfirmed)
      confirm_last_user
      user
    end

    def sign_up_with_backup_codes
      user = create(:user, :unconfirmed, :with_backup_code)
      confirm_last_user
      user
    end

    def sign_up_and_set_password
      user = sign_up
      user.password = VALID_PASSWORD
      fill_in t('forms.password'), with: user.password
      fill_in t('components.password_confirmation.confirm_label'), with: user.password
      click_button t('forms.buttons.continue')
      user
    end

    def sign_up_with_backup_codes_and_set_password
      user = sign_up_with_backup_codes
      fill_in t('forms.password'), with: VALID_PASSWORD
      click_button t('forms.buttons.continue')
      user
    end

    def sign_in_user(user = create(:user), email = nil)
      email ||= user.email_addresses.first.email
      signin(email, user.password)
      user
    end

    def sign_in_user_with_piv(user = user_with_piv_cac)
      signin_with_piv(user)
      user
    end

    def sign_in_before_2fa(user = create(:user))
      login_as(user, scope: :user, run_callbacks: false)

      if MfaPolicy.new(user).two_factor_enabled?
        Warden.on_next_request do |proxy|
          session = proxy.env['rack.session']
          session['warden.user.user.session'] = {}
          session['warden.user.user.session']['need_two_factor_authentication'] = true
        end
      end

      visit account_path
      user
    end

    def sign_in_with_warden(user, auth_method: nil, issuer: nil)
      login_as(user, scope: :user, run_callbacks: false)

      Warden.on_next_request do |proxy|
        session = proxy.env['rack.session']
        session['warden.user.user.session'] = {}.with_indifferent_access
        if auth_method
          session['warden.user.user.session']['auth_events'] = [{ auth_method:, at: Time.zone.now }]
        end
        session['sp'] = { issuer: } if issuer
      end
      visit account_path
    end

    def sign_in_and_2fa_user(user = user_with_2fa, issuer: nil)
      sign_in_with_warden(user, auth_method: 'phone', issuer:)
      user
    end

    def expire_reauthn_window
      Warden.on_next_request do |proxy|
        proxy.env['rack.session']['warden.user.user.session']['auth_events'].last[:at] =
          IdentityConfig.store.reauthn_window.seconds.ago
      end
    end

    def user_with_2fa
      create(:user, :fully_registered, with: { phone: IAL1_USER_PHONE }, password: VALID_PASSWORD)
    end

    def user_verified
      create(:user, :proofed)
    end

    def user_verified_with_gpo
      create(:user, :proofed_with_gpo)
    end

    def user_with_totp_2fa
      create(:user, :fully_registered, :with_authentication_app, password: VALID_PASSWORD)
    end

    def user_with_phishing_resistant_2fa
      create(:user, :fully_registered, :with_webauthn, password: VALID_PASSWORD)
    end

    def user_with_piv_cac
      create(
        :user, :fully_registered, :with_piv_or_cac,
        with: { phone: '+1 (703) 555-0000' },
        password: VALID_PASSWORD
      )
    end

    def confirm_last_user
      @raw_confirmation_token, = Devise.token_generator.generate(EmailAddress, :confirmation_token)

      User.last.email_addresses.first.update(
        confirmation_token: @raw_confirmation_token, confirmation_sent_at: Time.zone.now,
      )

      visit sign_up_create_email_confirmation_path(
        confirmation_token: @raw_confirmation_token,
      )
    end

    def click_send_one_time_code
      click_button t('forms.buttons.send_one_time_code')
    end

    def sign_in_live_with_2fa(user = user_with_2fa)
      sign_in_user(user)
      uncheck(t('forms.messages.remember_device'))
      fill_in_code_with_last_phone_otp
      click_submit_default
      user
    end

    def sign_in_live_with_piv_cac(user = user_with_piv_cac)
      sign_in_user(user)
      allow(FeatureManagement).to receive(:development_and_identity_pki_disabled?).and_return(true)
      visit login_two_factor_piv_cac_path
      stub_piv_cac_service
      visit_piv_cac_service(
        dn: 'C=US, O=U.S. Government, OU=DoD, OU=PKI, CN=DOE.JOHN.1234',
        uuid: user.piv_cac_configurations.first.x509_dn_uuid,
      )
    end

    def fill_in_code_with_last_phone_otp
      accept_rules_of_use_and_continue_if_displayed
      fill_in I18n.t('components.one_time_code_input.label'), with: last_phone_otp
    end

    def fill_in_code_with_last_totp(user)
      accept_rules_of_use_and_continue_if_displayed
      fill_in 'code', with: last_totp(user)
    end

    def accept_rules_of_use_and_continue_if_displayed
      return unless current_path == rules_of_use_path
      check 'rules_of_use_form[terms_accepted]'
      click_button t('forms.buttons.continue')
    end

    def click_submit_default
      click_button t('forms.buttons.submit.default')
    end

    def click_submit_default_twice
      click_button t('forms.buttons.submit.default')
      click_button t('forms.buttons.submit.default')
    end

    def click_continue
      click_button t('forms.buttons.continue') if page.has_button?(t('forms.buttons.continue'))
    end

    def click_agree_and_continue
      click_button t('sign_up.agree_and_continue')
    end

    def click_agree_and_continue_optional
      return unless page.has_button?(t('sign_up.agree_and_continue'))
      click_button t('sign_up.agree_and_continue')
    end

    def enter_correct_otp_code_for_user(user)
      fill_in 'code', with: user.reload.direct_otp
      click_submit_default
    end

    def perform_in_browser(name)
      old_session = Capybara.session_name
      Capybara.session_name = name
      yield
      Capybara.session_name = old_session
    end

    def sign_in_with_totp_enabled_user
      user = build(:user, :fully_registered, :with_authentication_app, password: VALID_PASSWORD)
      sign_in_user(user)
      fill_in 'code', with: generate_totp_code(@secret)
      click_submit_default
    end

    def acknowledge_and_confirm_personal_key
      click_acknowledge_personal_key
    end

    def click_acknowledge_personal_key
      checkbox_header = t('forms.personal_key.required_checkbox')
      find('label', text: /#{checkbox_header}/).click
      click_continue
    end

    def enter_personal_key(personal_key:, selector: 'input[type="text"]')
      field = page.find(selector)

      expect(field[:autocapitalize]).to eq('none')
      expect(field[:autocomplete]).to eq('off')
      expect(field[:spellcheck]).to eq('false')

      field.set(personal_key)
    end

    def cookies
      page.driver.browser.rack_mock_session.cookie_jar.instance_variable_get(:@cookies)
    end

    def session_cookie
      cookies.find { |cookie| cookie.name == '_identity_idp_session' }
    end

    def session_store
      config = Rails.application.config
      config.session_store.new({}, config.session_options)
    end

    def sign_up_user_from_sp_without_confirming_email(email)
      sp_request_id = ServiceProviderRequestProxy.last.uuid

      expect(current_url).to eq new_user_session_url
      expect_branded_experience

      click_sign_in_from_landing_page_then_click_create_account

      expect(current_url).to eq sign_up_email_url
      expect_branded_experience

      visit_landing_page_and_click_create_account_with_request_id(sp_request_id)

      expect(current_url).to eq sign_up_email_url
      expect_branded_experience

      submit_form_with_invalid_email

      expect(current_url).to eq sign_up_email_url
      expect_branded_experience

      submit_form_with_valid_but_wrong_email

      expect(current_url).to eq sign_up_verify_email_url
      expect_branded_experience

      click_link_to_use_a_different_email

      expect(current_url).to eq sign_up_email_url
      expect_branded_experience

      submit_form_with_valid_email(email)

      expect(current_url).to eq sign_up_verify_email_url
      expect(last_email.html_part.body.raw_source).to include "?_request_id=#{sp_request_id}"
      expect_branded_experience

      click_link_to_resend_the_email

      expect(current_url).to eq sign_up_verify_email_url(resend: true)
      expect_branded_experience

      attempt_to_confirm_email_with_invalid_token(sp_request_id)

      expect(current_url).to eq sign_up_email_resend_url(request_id: sp_request_id)

      submit_resend_email_confirmation_form_with_correct_email(email)

      expect(last_email.html_part.body.raw_source).to include "?_request_id=#{sp_request_id}"
    end

    def confirm_email_in_a_different_browser(email)
      click_confirmation_link_in_email(email)

      expect_branded_experience

      submit_form_with_invalid_password

      expect_branded_experience

      submit_form_with_valid_password

      set_up_2fa_with_valid_phone
      skip_second_mfa_prompt
    end

    def click_sign_in_from_landing_page_then_click_create_account
      click_link t('links.create_account')
    end

    def visit_landing_page_and_click_create_account_with_request_id(request_id)
      visit new_user_session_url(request_id: request_id)
      click_link t('links.create_account')
    end

    def submit_form_with_invalid_email
      check t('sign_up.terms', app_name: APP_NAME)
      fill_in t('forms.registration.labels.email'), with: 'invalidemail'
      click_button t('forms.buttons.submit.default')
    end

    def submit_form_with_valid_but_wrong_email
      check t('sign_up.terms', app_name: APP_NAME)
      fill_in t('forms.registration.labels.email'), with: 'test@example.com'
      click_button t('forms.buttons.submit.default')
    end

    def click_link_to_use_a_different_email
      click_link t('notices.use_diff_email.link').upcase_first
    end

    def submit_form_with_valid_email(email = 'test@test.com')
      check t('sign_up.terms', app_name: APP_NAME)
      fill_in t('forms.registration.labels.email'), with: email
      click_button t('forms.buttons.submit.default')
    end

    def click_link_to_resend_the_email
      click_button 'Resend'
    end

    def attempt_to_confirm_email_with_invalid_token(request_id)
      visit sign_up_create_email_confirmation_url(
        _request_id: request_id, confirmation_token: 'foo',
      )
    end

    def submit_resend_email_confirmation_form_with_correct_email(email)
      fill_in t('forms.registration.labels.email'), with: email
      click_button t('forms.buttons.resend_confirmation')
    end

    def click_confirmation_link_in_email(email)
      open_email(email)
      visit_in_email(t('user_mailer.email_confirmation_instructions.link_text'))
    end

    def submit_form_with_invalid_password
      fill_in t('forms.password'), with: 'invalid'
      click_button t('forms.buttons.continue')
    end

    def submit_form_with_valid_password(password = VALID_PASSWORD)
      fill_in t('forms.password'), with: password
      fill_in t('components.password_confirmation.confirm_label'), with: password
      click_button t('forms.buttons.continue')
    end

    def set_up_2fa_with_valid_phone
      select_2fa_option('phone')
      fill_in 'new_phone_form[phone]', with: '202-555-1212'
      click_send_one_time_code
      fill_in_code_with_last_phone_otp
      click_submit_default
    end

    def set_up_mfa_with_valid_phone
      fill_in 'new_phone_form[phone]', with: '202-555-1212'
      click_send_one_time_code
      fill_in_code_with_last_phone_otp
      click_submit_default
    end

    def set_up_mfa_with_backup_codes
      click_on t('forms.buttons.continue')
      click_on t('forms.buttons.continue')
    end

    def register_user(email = 'test@test.com')
      confirm_email_and_password(email)
      set_up_2fa_with_valid_phone
      skip_second_mfa_prompt
      User.find_with_email(email)
    end

    def confirm_email(email)
      visit sign_up_email_path
      submit_form_with_valid_email(email)
      click_confirmation_link_in_email(email)
    end

    def confirm_email_and_password(email)
      find_link(t('links.create_account')).click
      submit_form_with_valid_email(email)
      click_confirmation_link_in_email(email)
      submit_form_with_valid_password
    end

    def register_user_with_authenticator_app(email = 'test@test.com')
      confirm_email_and_password(email)
      set_up_2fa_with_authenticator_app
      skip_second_mfa_prompt
    end

    def set_up_2fa_with_authenticator_app
      select_2fa_option('auth_app')

      expect(page).to have_current_path authenticator_setup_path

      fill_in_totp_name

      secret = find('#qr-code').text
      code_field = find('[aria-labelledby="totp-step-4-label"]')
      totp_code = generate_totp_code(secret)
      code_field.set(totp_code)

      click_button 'Submit'
    end

    def set_up_2fa_with_backup_codes
      select_2fa_option('backup_code')
      
      expect(page).to have_current_path auth_method_confirmation_path
    end

    def register_user_with_piv_cac(email = 'test@test.com')
      confirm_email_and_password(email)
      expect(page).to have_current_path authentication_methods_setup_path
      expect(page).to have_content(
        t('two_factor_authentication.two_factor_choice_options.piv_cac'),
      )

      set_up_2fa_with_piv_cac
      skip_second_mfa_prompt
    end

    def set_up_2fa_with_piv_cac
      stub_piv_cac_service
      select_2fa_option('piv_cac')

      expect(page).to have_current_path setup_piv_cac_path

      nonce = piv_cac_nonce_from_form_action
      visit_piv_cac_service(
        setup_piv_cac_url,
        nonce: nonce,
        uuid: SecureRandom.uuid,
        subject: 'SomeIgnoredSubject',
      )
    end

    def skip_second_mfa_prompt
      click_on t('mfa.skip')
    end

    def sign_in_via_branded_page(user)
      fill_in_credentials_and_submit(user.confirmed_email_addresses.first.email, user.password)
      fill_in_code_with_last_phone_otp
      click_submit_default
    end

    def stub_piv_cac_service
      allow(IdentityConfig.store).to receive(:identity_pki_disabled).and_return(false)
      allow(IdentityConfig.store).to receive(:piv_cac_service_url).
        and_return('http://piv.example.com/')
      allow(IdentityConfig.store).to receive(:piv_cac_verify_token_url).and_return('http://piv.example.com/')
      stub_request(:post, 'piv.example.com').to_return do |request|
        {
          status: 200,
          body: CGI.unescape(request.body.sub(/^token=/, '')),
        }
      end
    end

    def visit_piv_cac_service(idp_url, token_data)
      visit(idp_url + '?token=' + CGI.escape(token_data.to_json))
    end

    def visit_login_two_factor_piv_cac_and_get_nonce
      visit login_two_factor_piv_cac_path
      get_piv_cac_nonce_from_link(find_link(t('forms.piv_cac_mfa.submit')))
    end

    # This is a bit convoluted because we generate a nonce when we visit the
    # link. The link provides a redirect to the piv/cac service with the nonce.
    # This way, even if JavaScript fetches the link to grab the nonce, a new nonce
    # is generated when the user clicks on the link.
    def get_piv_cac_nonce_from_link(link)
      go_back = current_path
      visit link['href']
      nonce = Rack::Utils.parse_nested_query(URI(current_url).query)['nonce']
      visit go_back
      nonce
    end

    def piv_cac_nonce_from_form_action
      go_back = current_path
      fill_in 'name', with: 'Card ' + SecureRandom.uuid
      click_button t('forms.piv_cac_setup.submit')
      nonce = Rack::Utils.parse_nested_query(URI(current_url).query)['nonce']
      visit go_back
      nonce
    end

    def link_identity(user, service_provider, ial = nil)
      IdentityLinker.new(
        user,
        service_provider,
      ).link_identity(
        ial: ial,
      )
    end

    def set_new_browser_session
      # For when we want to login from a new browser to avoid the default 'remember device' behavior
      Capybara.reset_session!
    end

    def fill_forgot_password_form(user)
      click_link t('links.passwords.forgot')
      fill_in t('account.index.email'), with: user.email
      click_button t('forms.buttons.continue')

      expect(current_path).to eq forgot_password_path
    end

    def click_reset_password_link_from_email
      expect(last_email.subject).to eq t('user_mailer.reset_password_instructions.subject')
      expect(last_email.html_part.body).to include MarketingSite.help_url
      expect(last_email.html_part.body).to have_content(
        t(
          'user_mailer.reset_password_instructions.footer',
          expires: (Devise.reset_password_within / 3600),
        ),
      )
      open_last_email
      click_email_link_matching(/reset_password_token/)

      expect(page.html).not_to include(t('notices.dap_participation'))
      expect(current_path).to eq edit_user_password_path
    end

    def fill_reset_password_form
      fill_in t('forms.passwords.edit.labels.password'), with: 'newVal!dPassw0rd'
      click_button t('forms.passwords.edit.buttons.submit')

      expect(current_path).to eq new_user_session_path
    end

    def expect_branded_experience
      # Check for branded experience as being the header containing the Login.gov and partner logos
      expect(page).to have_css(".page-header--basic img[alt='#{APP_NAME}'] ~ img")
    end

    def acknowledge_backup_code_confirmation
      click_on t('two_factor_authentication.backup_codes.saved_backup_codes')
    end

    def set_hidden_field(id, value)
      input = first("input##{id}", visible: false)
      if javascript_enabled?
        input.execute_script("this.value = #{value.to_json}")
      else
        input.set(value)
      end
    end
  end
end
