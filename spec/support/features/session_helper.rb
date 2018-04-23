module Features
  module SessionHelper
    VALID_PASSWORD = 'Val!d Pass w0rd'.freeze

    def sign_up_with(email)
      visit sign_up_email_path
      fill_in 'Email', with: email
      click_button t('forms.buttons.submit.default')
    end

    def sign_up_and_2fa_loa1_user
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      user = sign_up_and_set_password
      fill_in 'Phone', with: '202-555-1212'
      click_send_security_code
      click_submit_default
      click_acknowledge_personal_key
      user
    end

    def signin(email, password)
      visit new_user_session_path
      fill_in_credentials_and_submit(email, password)
    end

    def fill_in_credentials_and_submit(email, password)
      fill_in 'user_email', with: email
      fill_in 'user_password', with: password
      click_button t('links.next')
    end

    def sign_up
      user = create(:user, :unconfirmed)
      confirm_last_user
      user
    end

    def begin_sign_up_with_sp_and_loa(loa3:)
      user = create(:user)
      login_as(user, scope: :user, run_callbacks: false)

      Warden.on_next_request do |proxy|
        session = proxy.env['rack.session']
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        session[:sp] = { loa3: loa3, issuer: sp.issuer }
      end

      visit account_path
      user
    end

    def sign_up_and_set_password
      user = sign_up
      fill_in 'password_form_password', with: VALID_PASSWORD
      click_button t('forms.buttons.continue')
      user
    end

    def sign_in_user(user = create(:user))
      signin(user.email, user.password)
      user
    end

    def sign_in_before_2fa(user = create(:user))
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      login_as(user, scope: :user, run_callbacks: false)

      if user.phone.present?
        Warden.on_next_request do |proxy|
          session = proxy.env['rack.session']
          session['warden.user.user.session'] = {}
          session['warden.user.user.session']['need_two_factor_authentication'] = true
        end
      end

      visit account_path
      user
    end

    def sign_in_with_warden(user)
      login_as(user, scope: :user, run_callbacks: false)
      allow(user).to receive(:need_two_factor_authentication?).and_return(false)

      Warden.on_next_request do |proxy|
        session = proxy.env['rack.session']
        session['warden.user.user.session'] = { authn_at: Time.zone.now }
      end
      visit account_path
    end

    def sign_in_and_2fa_user(user = user_with_2fa)
      sign_in_with_warden(user)
      user
    end

    def user_with_2fa
      create(:user, :signed_up, phone: '+1 (555) 555-0000', password: VALID_PASSWORD)
    end

    def confirm_last_user
      @raw_confirmation_token, = Devise.token_generator.generate(User, :confirmation_token)

      User.last.update(
        confirmation_token: @raw_confirmation_token, confirmation_sent_at: Time.zone.now
      )
      visit sign_up_create_email_confirmation_path(
        confirmation_token: @raw_confirmation_token
      )
    end

    def click_send_security_code
      stub_twilio_service
      click_button t('forms.buttons.send_security_code')
    end

    def sign_in_live_with_2fa(user = user_with_2fa)
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      sign_in_user(user)
      click_submit_default
      user
    end

    def click_submit_default
      click_button t('forms.buttons.submit.default')
    end

    def click_continue
      click_button t('forms.buttons.continue') if page.has_button?(t('forms.buttons.continue'))
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
      user = build(:user, :signed_up, password: VALID_PASSWORD)
      @secret = user.generate_totp_secret
      UpdateUser.new(user: user, attributes: { otp_secret_key: @secret }).call
      sign_in_user(user)
      fill_in 'code', with: generate_totp_code(@secret)
      click_submit_default
    end

    def acknowledge_and_confirm_personal_key
      extra_characters_get_ignored = 'abc123qwerty'
      code_words = []

      page.all(:css, '[data-personal-key]').map do |node|
        code_words << node.text
      end

      button_text = t('forms.buttons.continue')

      click_on button_text, class: 'personal-key-continue'

      fill_in 'personal_key', with: code_words.join('-').downcase + extra_characters_get_ignored

      click_on button_text, class: 'personal-key-confirm'
    end

    def click_acknowledge_personal_key
      click_on t('forms.buttons.continue'), class: 'personal-key-continue'
    end

    def enter_personal_key(personal_key:, selector: 'input[type="text"]')
      field = page.find(selector)

      expect(field[:autocapitalize]).to eq('none')
      expect(field[:autocomplete]).to eq('off')
      expect(field[:spellcheck]).to eq('false')

      field.set(personal_key)
    end

    def loa1_sp_session
      Warden.on_next_request do |proxy|
        session = proxy.env['rack.session']
        sp = ServiceProvider.from_issuer('http://localhost:3000')
        session[:sp] = {
          loa3: false,
          issuer: sp.issuer,
          requested_attributes: [:email],
        }
      end
    end

    def loa3_sp_session(request_url: 'http://localhost:3000')
      Warden.on_next_request do |proxy|
        session = proxy.env['rack.session']
        session[:sp] = { loa3: true, request_url: request_url }
      end
    end

    def cookies
      page.driver.browser.rack_mock_session.cookie_jar.instance_variable_get(:@cookies)
    end

    def session_cookie
      cookies.find { |cookie| cookie.name == '_upaya_session' }
    end

    def session_store
      config = Rails.application.config
      config.session_store.new({}, config.session_options)
    end

    def sign_up_user_from_sp_without_confirming_email(email)
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      sp_request_id = ServiceProviderRequest.last.uuid

      expect(current_url).to eq sign_up_start_url(request_id: sp_request_id)

      click_sign_in_from_landing_page_then_click_create_account

      expect(current_url).to eq sign_up_email_url(request_id: sp_request_id)

      visit_landing_page_and_click_create_account_with_request_id(sp_request_id)

      expect(current_url).to eq sign_up_email_url(request_id: sp_request_id)
      expect(page).to have_css('img[src*=sp-logos]')

      submit_form_with_invalid_email

      expect(current_url).to eq sign_up_email_url
      expect(page).to have_css('img[src*=sp-logos]')

      submit_form_with_valid_but_wrong_email

      expect(current_url).to eq sign_up_verify_email_url(request_id: sp_request_id)
      expect(page).to have_css('img[src*=sp-logos]')

      click_link_to_use_a_different_email

      expect(current_url).to eq sign_up_email_url(request_id: sp_request_id)
      expect(page).to have_css('img[src*=sp-logos]')

      submit_form_with_valid_email(email)

      expect(current_url).to eq sign_up_verify_email_url(request_id: sp_request_id)
      expect(last_email.html_part.body).to have_content "?_request_id=#{sp_request_id}"
      expect(page).to have_css('img[src*=sp-logos]')

      click_link_to_resend_the_email

      expect(current_url).to eq sign_up_verify_email_url(request_id: sp_request_id, resend: true)
      expect(page).to have_css('img[src*=sp-logos]')

      attempt_to_confirm_email_with_invalid_token(sp_request_id)

      expect(current_url).to eq sign_up_email_resend_url(request_id: sp_request_id)

      submit_resend_email_confirmation_form_with_correct_email(email)

      expect(last_email.html_part.body).to have_content "?_request_id=#{sp_request_id}"
    end

    def confirm_email_in_a_different_browser(email)
      click_confirmation_link_in_email(email)

      expect(page).to have_css('img[src*=sp-logos]')

      submit_form_with_invalid_password

      expect(page).to have_css('img[src*=sp-logos]')

      submit_form_with_valid_password

      expect(page).to have_css('img[src*=sp-logos]')

      set_up_2fa_with_valid_phone

      expect(page).to have_css('img[src*=sp-logos]')

      click_submit_default

      # expect(page).to have_css('img[src*=sp-logos]')

      click_acknowledge_personal_key
    end

    def click_sign_in_from_landing_page_then_click_create_account
      click_link t('links.sign_in')
      click_link t('links.create_account')
    end

    def visit_landing_page_and_click_create_account_with_request_id(request_id)
      visit sign_up_start_url(request_id: request_id)
      click_link t('sign_up.registrations.create_account')
    end

    def submit_form_with_invalid_email
      fill_in 'Email', with: 'invalidemail'
      click_button t('forms.buttons.submit.default')
    end

    def submit_form_with_valid_but_wrong_email
      fill_in 'Email', with: 'test@example.com'
      click_button t('forms.buttons.submit.default')
    end

    def click_link_to_use_a_different_email
      click_link t('notices.use_diff_email.link')
    end

    def submit_form_with_valid_email(email = 'test@test.com')
      fill_in 'Email', with: email
      click_button t('forms.buttons.submit.default')
    end

    def click_link_to_resend_the_email
      click_button 'Resend'
    end

    def attempt_to_confirm_email_with_invalid_token(request_id)
      visit sign_up_create_email_confirmation_url(
        _request_id: request_id, confirmation_token: 'foo'
      )
    end

    def submit_resend_email_confirmation_form_with_correct_email(email)
      fill_in 'Email', with: email
      click_button t('forms.buttons.resend_confirmation')
    end

    def click_confirmation_link_in_email(email)
      open_email(email)
      visit_in_email(t('mailer.confirmation_instructions.link_text'))
    end

    def submit_form_with_invalid_password
      fill_in 'Password', with: 'invalid'
      click_button t('forms.buttons.continue')
    end

    def submit_form_with_valid_password(password = VALID_PASSWORD)
      fill_in 'Password', with: password
      click_button t('forms.buttons.continue')
    end

    def set_up_2fa_with_valid_phone
      fill_in 'user_phone_form[phone]', with: '202-555-1212'
      click_send_security_code
    end

    def register_user(email = 'test@test.com')
      confirm_email_and_password(email)
      set_up_2fa_with_valid_phone
      click_submit_default
      User.find_with_email(email)
    end

    def confirm_email_and_password(email)
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      click_link t('sign_up.registrations.create_account')
      submit_form_with_valid_email(email)
      click_confirmation_link_in_email(email)
      submit_form_with_valid_password
    end

    def register_user_with_authenticator_app(email = 'test@test.com')
      confirm_email_and_password(email)
      set_up_2fa_with_authenticator_app
    end

    def set_up_2fa_with_authenticator_app
      click_link t('links.two_factor_authentication.app_option')

      expect(page).to have_current_path authenticator_setup_path

      secret = find('#qr-code').text
      fill_in 'code', with: generate_totp_code(secret)
      click_button 'Submit'
    end

    def sign_in_via_branded_page(user)
      allow(FeatureManagement).to receive(:prefill_otp_codes?).and_return(true)
      click_link t('links.sign_in')
      fill_in_credentials_and_submit(user.email, user.password)
      click_submit_default
    end

    def stub_twilio_service
      twilio_service = instance_double(TwilioService)
      allow(twilio_service).to receive(:send_sms)
      allow(twilio_service).to receive(:place_call)

      allow(TwilioService).to receive(:new).and_return(twilio_service)
    end

    def link_identity(user, client_id, ial = nil)
      IdentityLinker.new(
        user,
        client_id
      ).link_identity(
        ial: ial
      )
    end
  end
end
