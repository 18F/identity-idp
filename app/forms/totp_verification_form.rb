class TotpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    FormResponse.new(success: valid_totp_code?, errors: {}, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :code

  def valid_totp_code?
    code_length = Devise.otp_length
    return false unless code =~ /\A\d{#{code_length}}\Z/
    user.authenticate_totp(code)
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'totp',
    }
  end
end
