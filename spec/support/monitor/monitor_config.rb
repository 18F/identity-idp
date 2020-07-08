# Manages all the environment variables used in smoke tests
class MonitorConfig
  def initialize(local: local)
    @local = local
  end

  def local?
    @local
  end

  def check_env_variables!
    expected_env_vars = %w[
      MONITOR_EMAIL
      MONITOR_EMAIL_PASSWORD
      MONITOR_GOOGLE_VOICE_PHONE
      MONITOR_SMS_SIGN_IN_EMAIL
      MONITOR_ENV
    ]
    missing_env_vars = expected_env_vars - ENV.keys

    message = <<~MESSAGE.squish
      make sure environment variables (#{missing_env_vars.join(', ')})
      are in the CircleCI config, or have been exported properly if running
      locally
    MESSAGE

    raise message unless missing_env_vars.empty?
  end

  def email_address
    ENV['MONITOR_EMAIL'] || 'test@example.com'
  end

  # A phone number that has been configured to forward SMS messages to MONITOR_EMAIL
  def google_voice_phone
    ENV['MONITOR_GOOGLE_VOICE_PHONE'] || '18888675309'
  end

  # An email that already has an account created, used for testing the password reset flow
  def sms_sign_in_email
    ENV['MONITOR_SMS_SIGN_IN_EMAIL'] || 'test+sms@example.com'
  end

  def password
    ENV['MONITOR_EMAIL_PASSWORD'] || 'salty pickles'
  end

  def monitor_env
    ENV['MONITOR_ENV'].to_s.upcase
  end

  # Looks up the OIDC service provider for that environment, example key: MONITOR_INT_OIDC_SP_URL
  def oidc_sp_url
    ENV["MONITOR_#{monitor_env}_OIDC_SP_URL"] || (local? && '/test/oidc')
  end

  # Looks up the SML service provider for that environment, example key: MONITOR_INT_SAML_SP_URL
  def saml_sp_url
    ENV["MONITOR_#{monitor_env}_SAML_SP_URL"] || (local? && '/test/saml/login')
  end

  # Looks up the IDP for that environment, example key: MONITOR_IDP_URL
  def idp_signin_url
    ENV["MONITOR_#{monitor_env}_IDP_URL"]
  end
end
