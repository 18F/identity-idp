require 'saml_idp_constants'
require 'custom_devise_failure_app'
require 'mailable'

Devise.setup do |config|
  include Mailable
  require 'devise/orm/active_record'
  config.allow_unconfirmed_access_for = 0.days
  config.case_insensitive_keys = []
  config.confirm_within = 24.hours
  config.expire_all_remember_me_on_sign_out = true
  config.mailer_sender = email_with_name(
    IdentityConfig.store.email_from,
    IdentityConfig.store.email_from_display_name,
  )
  config.paranoid = true
  config.password_length = 12..128
  config.reset_password_within = 6.hours
  config.secret_key = IdentityConfig.store.secret_key_base
  config.sign_in_after_reset_password = false
  config.sign_out_via = :delete
  config.skip_session_storage = [:http_auth]
  config.strip_whitespace_keys = []
  config.stretches = Rails.env.test? ? 1 : 12
  config.timeout_in = IdentityConfig.store.session_timeout_in_minutes.minutes

  config.warden do |manager|
    manager.failure_app = CustomDeviseFailureApp
  end
end

Warden::Manager.after_authentication do |user, auth, options|
  if auth.env['action_dispatch.cookies']
    expected_cookie_value = "#{user.class}-#{user.id}"
    actual_cookie_value = auth.env['action_dispatch.cookies'].
      signed[TwoFactorAuthenticatable::REMEMBER_2FA_COOKIE]
    bypass_by_cookie = actual_cookie_value == expected_cookie_value
  end

  unless bypass_by_cookie
    auth.session(options[:scope])[TwoFactorAuthenticatable::NEED_AUTHENTICATION] =
      user.need_two_factor_authentication?(auth.request)
  end
end
