# Manages all the environment variables used in smoke tests
class MonitorConfig
  def check_env_variables!
    expected_env_vars = %w[EMAIL EMAIL_PASSWORD GOOGLE_VOICE_PHONE SMS_SIGN_IN_EMAIL LOWER_ENV]
    missing_env_vars = expected_env_vars - ENV.keys

    message = <<~MESSAGE
      make sure environment variables (#{missing_env_vars.join(', ')})
      are in the CircleCI config, or have been exported properly if running
      locally
    MESSAGE

    raise message unless missing_env_vars.empty?
  end

  def email_address
    ENV['EMAIL'] || 'test@example.com'
  end

  # A phone number that has been configured to forward SMS messages to EMAIL
  def google_voice_phone
    ENV['GOOGLE_VOICE_PHONE'] || '18888675309'
  end

  # An email that already has an account created, used for testing the password reset flow
  def sms_sign_in_email
    ENV['SMS_SIGN_IN_EMAIL'] || 'test+sms@example.com'
  end

  def password
    ENV['EMAIL_PASSWORD'] || 'salty pickles'
  end

  def lower_env
    ENV['LOWER_ENV']
  end

  def oidc_sp_url
    ENV["#{lower_env}_OIDC_SP_URL"]
  end

  def saml_sp_url
    ENV["#{lower_env}_SAML_SP_URL"]
  end

  def idp_signin_url
    ENV["#{lower_env}_IDP_URL"]
  end
end