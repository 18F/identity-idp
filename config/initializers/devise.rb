require 'saml_idp_constants'

Devise.setup do |config|
  include Mailable
  require 'devise/orm/active_record'
  config.allow_unconfirmed_access_for = 0.days
  config.case_insensitive_keys = [:email]
  config.confirm_within = 24.hours
  config.expire_all_remember_me_on_sign_out = true
  config.mailer = 'CustomDeviseMailer'
  config.mailer_sender = email_with_name(Figaro.env.email_from, Figaro.env.email_from)
  config.paranoid = true
  config.password_length = 8..128
  config.reconfirmable = true
  config.reset_password_within = 6.hours
  config.secret_key = Figaro.env.secret_key_base
  config.sign_in_after_reset_password = false
  config.sign_out_via = :delete
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.strip_whitespace_keys = [:email]
  config.timeout_in = Figaro.env.session_timeout_in_minutes.to_i.minutes

  # ==> Two Factor Authentication
  config.allowed_otp_drift_seconds = 30
  config.direct_otp_length = 6
  config.direct_otp_valid_for = Figaro.env.otp_valid_for.to_i.minutes
  config.max_login_attempts = 3 # max OTP login attempts, not devise strategies (e.g. pw auth)
  config.otp_length = 6
end
