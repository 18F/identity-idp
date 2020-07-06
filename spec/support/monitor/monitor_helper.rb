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
      # local testing of remote things
      require 'dotenv'
      Dotenv.load

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
    password_reset_link_regex = /(?<link>https?:.+reset_password_token=[\w\-]+)/

    if local?
      body = ActionMailer::Base.deliveries.last.body.parts.first.to_s
      if (match_data = body.match(password_reset_link_regex))
        to_local_url(match_data[:link])
      end
    else
      sleep_and_check do
        gmail.inbox_unread.each do |email|
          next unless email.subject == 'Reset your password'
          body = email.message.parts.first.body
          if (match_data = body.match(password_reset_link_regex))
            email.read!
            break match_data[:link]
          end
        end
      end
    end
  end

  def check_for_confirmation_link
    confirmation_link_regex = /(?<link>https?:.+confirmation_token=[\w\-]+)/

    if local?
      body = ActionMailer::Base.deliveries.last.body.parts.first.to_s
      if (match_data = body.match(confirmation_link_regex))
        to_local_url(match_data[:link])
      end
    else
      subjects = [
        'Confirm your email',
        'Email not found'
      ]

      sleep_and_check do
        gmail.inbox_unread.each do |email|
          next unless subjects.include?(email.subject)
          body = email.message.parts.first.body
          if (match_data = body.match(confirmation_link_regex))
            email.read!
            break match_data[:link]
          end
        end
      end
    end
  end

  def check_for_otp
    otp_regex = /Enter (?<code>\d{6}) in login\.gov/

    if local?
      match_data = Telephony::Test::Message.messages.last.body.match(otp_regex)
      return match_data[:code] if match_data
    else
      sleep_and_check do
        gmail.inbox_unread.each do |email|
          body = email.message.parts.first.body
          match_data = body.match(otp_regex)

          next unless match_data

          email.read!
          break match_data[:code]
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
    context.expect(confirmation_link).to context.be_present
    # puts "Visiting #{confirmation_link}"
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

    # puts "created account for #{email_address}"
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
