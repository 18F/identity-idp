class OtpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    FormResponse.new(
      success: valid_direct_otp_code?,
      errors: {},
      extra: extra_analytics_attributes,
    )
  end

  private

  attr_reader :code, :user

  def valid_direct_otp_code?
    return false unless code.match? pattern_matching_otp_code_format
    user.authenticate_direct_otp(code)
  end

  def pattern_matching_otp_code_format
    /\A\d{#{otp_code_length}}\Z/
  end

  def otp_code_length
    Devise.direct_otp_length
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'otp_code',
    }
  end
end
