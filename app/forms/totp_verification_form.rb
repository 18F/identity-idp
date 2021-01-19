class TotpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    cfg = valid_totp_code?
    FormResponse.new(
      success: cfg.present?,
      errors: {},
      extra: extra_analytics_attributes(cfg&.id),
    )
  end

  private

  attr_reader :user, :code

  def valid_totp_code?
    return unless code.match? pattern_matching_totp_code_format
    Db::AuthAppConfiguration::Authenticate.call(user, code)
  end

  def pattern_matching_totp_code_format
    /\A\d{#{totp_code_length}}\Z/
  end

  def totp_code_length
    TwoFactorAuthenticatable::OTP_LENGTH
  end

  def extra_analytics_attributes(cfg_id)
    {
      multi_factor_auth_method: 'totp',
      mfa_id: cfg_id,
    }
  end
end
