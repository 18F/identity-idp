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
      regex: /(?<link>https?:.+reset_password_token=[\w\-]+)/,
    )
  end

  def check_for_confirmation_link
    scan_emails_and_extract(
      subjects: [
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
      scan_emails_and_extract(regex: otp_regex)
    end
  end

  def scan_emails_and_extract(regex:, subject: nil, subjects: nil)
    all_subjects = [*subject, *subjects]

    if local?
      body = ActionMailer::Base.deliveries.last.body.parts.first.to_s
      if (match_data = body.match(regex))
        return to_local_url(match_data[1])
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
            return match_data[1]
          end
        end
      end
    end

    raise "failed to find email that matched #{regex}"
  end

  def sleep_and_check(count: 5, sleep_duration: 3)
    count.times do
      result = yield

      return result if result.present?

      sleep sleep_duration
    end
  end
end
