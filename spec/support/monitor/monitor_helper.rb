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
      if (match = body.match(password_reset_link_regex))
        to_local_url(match[:link])
      end
    else
      sleep_and_check do
        gmail.inbox_unread.each do |email|
          next unless email.subject == 'Reset your password'
          body = email.message.parts.first.body
          if (match = body.match(password_reset_link_regex))
            email.read!
            break match[:link]
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
end
