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

  def email
    @email ||= MonitorEmailHelper.new(email: email_address, password: password, local: local?)
  end

  def setup
    if local?
      context.create(:user, email: sms_sign_in_email, password: password)
    else
      check_env_variables!
      reset_sessions
      email.inbox_clear
    end
  end

  def check_env_variables!
    expected_env_vars = %w[EMAIL EMAIL_PASSWORD GOOGLE_VOICE_PHONE SMS_SIGN_IN_EMAIL LOWER_ENV]
    missing_env_vars = expected_env_vars - ENV.keys

    message = <<~MESSAGE
      make sure environment variables (#{missing_env_vars.join(', ')})
      are in the CircleCI config, or have been exported properly if running
      locally
    MESSAGE

    context.expect(missing_env_vars). to context.be_empty, message
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
    email.scan_emails_and_extract(
      subject: 'Reset your password',
      regex: /(?<link>https?:.+reset_password_token=[\w\-]+)/,
    )
  end

  def check_for_confirmation_link
    email.scan_emails_and_extract(
      subject: [
        'Confirm your email',
        'Email not found',
      ],
      regex: /(?<link>https?:.+confirmation_token=[\w\-]+)/,
    )
  end

  def check_for_otp
    otp_regex = /Enter (?<code>\d{6}) in login\.gov/

    if local?
      match_data = Telephony::Test::Message.messages.last.body.match(otp_regex)
      return match_data[:code] if match_data
    else
      email.scan_emails_and_extract(regex: otp_regex)
    end
  end
end
