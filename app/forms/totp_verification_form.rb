class TotpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit(params)
    @ga_client_id = params[:ga_client_id]
    FormResponse.new(
      success: valid_totp_code?,
      errors: {},
      extra: extra_analytics_attributes(params),
    )
  end

  private

  attr_reader :user, :code, :ga_client_id

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
      ga_client_id: ga_client_id,
    }
  end
end
