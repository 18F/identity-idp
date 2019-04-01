class TotpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    FormResponse.new(
      success: valid_totp_code?,
      errors: {},
      extra: extra_analytics_attributes,
    )
  end

  private

  attr_reader :user, :code

  def valid_totp_code?
    return false unless code.match? pattern_matching_totp_code_format
    user.authenticate_totp(code)
  end

  def pattern_matching_totp_code_format
    /\A\d{#{totp_code_length}}\Z/
  end

  def totp_code_length
    Devise.otp_length
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'totp',
    }
  end
end
