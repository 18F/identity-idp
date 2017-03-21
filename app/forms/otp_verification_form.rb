class OtpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    FormResponse.new(success: valid_direct_otp_code?, errors: {})
  end

  private

  attr_reader :code, :user

  def valid_direct_otp_code?
    code_length = Devise.direct_otp_length
    return false unless code =~ /^\d{#{code_length}}$/
    user.authenticate_direct_otp(code)
  end
end
