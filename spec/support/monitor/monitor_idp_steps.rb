require 'rotp'

module MonitorIdpSteps
  def random_email_address
    random_str = SecureRandom.hex(12)
    monitor.config.email_address.dup.gsub(/@/, "+#{random_str}@")
  end

  def submit_password
    click_on 'Continue'
  end

  def click_send_otp
    click_on 'Send code'
  end

  def setup_backup_codes
    find("label[for='two_factor_options_form_selection_backup_code']").click
    click_on 'Continue'
    click_on 'Continue'
    click_on 'Continue'
  end

  # @return [String] email address for the account
  def create_new_account_up_until_password(email_address = random_email_address)
    fill_in 'user_email', with: email_address
    click_on 'Submit'
    confirmation_link = monitor.check_for_confirmation_link
    visit confirmation_link
    fill_in 'password_form_password', with: monitor.config.login_gov_sign_in_password
    submit_password

    email_address
  end

  # @return [String] email address for the account
  def create_new_account_with_sms
    email_address = create_new_account_up_until_password
    find("label[for='two_factor_options_form_selection_phone']").click
    click_on 'Continue'
    fill_in 'new_phone_form_phone', with: monitor.config.google_voice_phone
    click_send_otp
    otp = monitor.check_for_otp
    fill_in 'code', with: otp
    uncheck 'Remember this browser'
    click_on 'Submit'
    if current_path.match(/two_factor_options_success/)
      click_on 'Continue'
      setup_backup_codes
    end

    email_address
  end

  def sign_in_and_2fa(email)
    fill_in 'user_email', with: email
    fill_in 'user_password', with: monitor.config.login_gov_sign_in_password
    click_on 'Sign in'
    fill_in 'code', with: monitor.check_for_otp
    uncheck 'Remember this browser'
    click_on 'Submit'
  end

  # @return [String] email address for the account
  def create_new_account_with_totp
    email_address = create_new_account_up_until_password
    find("label[for='two_factor_options_form_selection_auth_app']").click
    click_on 'Continue'
    secret = find('#qr-code').text
    fill_in 'name', with: 'Authentication app'
    fill_in 'code', with: generate_totp_code(secret)
    click_button 'Submit'
    if current_path.match(/two_factor_options_success/)
      click_on 'Continue'
      setup_backup_codes
    end

    email_address
  end

  def generate_totp_code(secret)
    ROTP::TOTP.new(secret).at(Time.zone.now)
  end
end
