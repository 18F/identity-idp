require 'support/monitor/monitor_url_helper'

# For the "monitor" aka smoke tests
# This class and its method allow us to run the tests against local code so we
# can test in CI as well as against deployed environments
class MonitorHelper
  include MonitorUrlHelper

  attr_reader :context

  def initialize(context)
    @context = context
  end

  def gmail
    @gmail ||= GmailHelper.new(email_address, password)
  end

  def setup
    if local?
      context.create(:user, email: sms_sign_in_email, password: password)
    else
      reset_sessions
      gmail.inbox_clear
    end
  end

  def google_voice_phone
    ENV['GOOGLE_VOICE_PHONE'] || '18888675309'
  end

  def email_address
    ENV['EMAIL'] || 'test@example.com'
  end

  def sms_sign_in_email
    ENV['SMS_SIGN_IN_EMAIL'] || 'test+sms@example.com'
  end

  def password
    ENV['EMAIL_PASSWORD'] || 'salty pickles'
  end

  def local?
    defined?(Rails) && Rails.env.test?
  end

  def remote?
    !local?
  end

  # Capybara.reset_session! deletes the cookies for the current site. As such
  # we need to visit each site individually and reset there.
  def reset_sessions
    context.visit idp_signin_url
    Capybara.reset_session!
    context.visit oidc_sp_url if oidc_sp_url
    Capybara.reset_session!
    context.visit saml_sp_url if saml_sp_url
    Capybara.reset_session!
  end

  # local tests use "example.com" as the domain in emails but they actually
  # render on localhost, so we need to patch them to be relative
  def to_local_url(url)
    URI(url).tap do |uri|
      uri.scheme = nil
      uri.host = nil
    end.to_s
  end

  def check_for_password_reset_link
    scan_emails_and_extract(
      subject: 'Reset your password',
      regex: /(?<link>https?:.+reset_password_token=[\w\-]+)/
    )
  end

  def check_for_confirmation_link
    scan_emails_and_extract(
      subjects: [
        'Confirm your email',
        'Email not found',
      ],
      regex: /(?<link>https?:.+confirmation_token=[\w\-]+)/
    )
  end

  def check_for_otp
    otp_regex = /Enter (?<code>\d{6}) in login\.gov/

    if local?
      match_data = Telephony::Test::Message.messages.last.body.match(otp_regex)
      return match_data[:code] if match_data
    else
      scan_emails_and_extract(
        regex: otp_regex
      )
    end
  end

  def scan_emails_and_extract(regex:, subject: nil, subjects: nil)
    all_subjects = [*subject, *subjects]

    if local?
      body = ActionMailer::Base.deliveries.last.body.parts.first.to_s
      if (match_data = body.match(regex))
        to_local_url(match_data[1])
      end
    else
      sleep_and_check do
        gmail.inbox_unread.each do |email|
          if all_subjects.any?
            next unless all_subjects.include?(email.subject)
          end
          body = email.message.parts.first.body
          if (match_data = body.match(regex))
            email.read!
            break match_data[1]
          end
        end
      end
    end
  end

  def sleep_and_check(count: 5, sleep_duration: 3)
    count.times do
      result = yield

      return result if result.present?

      sleep sleep_duration
    end
    nil
  end

  def random_email_address
    random_str = SecureRandom.hex(12)
    email_address.dup.gsub(/@/, "+#{random_str}@")
  end

  def submit_password
    context.click_on 'Continue'
  end

  def click_send_otp
    context.click_on 'Send code'
  end

  def setup_backup_codes
    context.find("label[for='two_factor_options_form_selection_backup_code']").click
    context.click_on 'Continue'
    context.click_on 'Continue'
    context.click_on 'Continue'
  end

  # @return [String] email address for the account
  def create_new_account_up_until_password(email_address = random_email_address)
    context.fill_in 'user_email', with: email_address
    context.click_on 'Submit'
    confirmation_link = check_for_confirmation_link
    context.visit confirmation_link
    context.fill_in 'password_form_password', with: password
    submit_password

    email_address
  end

  # @return [String] email address for the account
  def create_new_account_with_sms
    email_address = create_new_account_up_until_password
    context.find("label[for='two_factor_options_form_selection_phone']").click
    context.click_on 'Continue'
    context.fill_in 'new_phone_form_phone', with: google_voice_phone
    click_send_otp
    otp = check_for_otp
    context.fill_in 'code', with: otp
    context.uncheck 'Remember this browser'
    context.click_on 'Submit'
    if context.current_path.match(/two_factor_options_success/)
      context.click_on 'Continue'
      setup_backup_codes
    end

    email_address
  end

  def sign_in_and_2fa(email)
    context.fill_in 'user_email', with: email
    context.fill_in 'user_password', with: password
    context.click_on 'Sign in'
    context.fill_in 'code', with: check_for_otp
    context.uncheck 'Remember this browser'
    context.click_on 'Submit'
  end
end
