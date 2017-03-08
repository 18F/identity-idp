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
    user.authenticate_direct_otp(code)
  end
end
