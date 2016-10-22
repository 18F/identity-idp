require 'saml_idp_constants'

Devise.setup do |config|
  require 'devise/orm/active_record'
  config.allow_unconfirmed_access_for = 0.days
  config.case_insensitive_keys = [:email]
  config.confirm_within = 24.hours
  config.expire_all_remember_me_on_sign_out = true
  config.mailer = 'CustomDeviseMailer'
  config.mailer_sender = Figaro.env.email_from
  config.paranoid = true
  config.password_length = 8..128
  config.pepper = Figaro.env.password_pepper
  config.reconfirmable = true
  config.reset_password_within = 6.hours
  config.secret_key = Figaro.env.secret_key_base
  config.sign_in_after_reset_password = false
  config.sign_out_via = :delete
  config.skip_session_storage = [:http_auth]

  # The scrypt encryptor ignores stretches but we keep for compatability.
  # We can set the scrypt config directly.
  # see https://github.com/pbhogan/scrypt
  # and https://github.com/capita/devise-scrypt
  # We set the test config much lower just to speed up tests.
  config.encryptor = :scrypt
  if Rails.env.test?
    SCrypt::Engine::DEFAULTS[:key_len] = 16
    SCrypt::Engine::DEFAULTS[:salt_size] = 8
    config.stretches = 1
  else
    SCrypt::Engine::DEFAULTS[:key_len] = 64
    SCrypt::Engine::DEFAULTS[:salt_size] = 32
    config.stretches = 12
  end

  config.strip_whitespace_keys = [:email]
  config.timeout_in = Figaro.env.session_timeout_in_minutes.to_i.minutes

  # ==> Two Factor Authentication
  config.allowed_otp_drift_seconds = 30
  config.direct_otp_length = 6
  config.direct_otp_valid_for = Figaro.env.otp_valid_for.to_i.minutes
  config.max_login_attempts = 3 # max OTP login attempts, not devise strategies (e.g. pw auth)
  config.otp_length = 6

  # zxcvbnable
  # The scores 0, 1, 2, 3 or 4 are given when the estimated crack time (seconds)
  # is less than 10**2, 10**4, 10**6, 10**8, Infinity.
  # Default minimum is 4 (best).
  # https://github.com/bitzesty/devise_zxcvbn
  config.min_password_score = 3
end
