class OtpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit(params)
    @ga_client_id = params[:ga_client_id]
    FormResponse.new(
      success: valid_direct_otp_code?,
      errors: {},
      extra: extra_analytics_attributes,
    )
  end

  private

  attr_reader :code, :user, :ga_client_id

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
      ga_client_id: :ga_client_id,
    }
  end
end
