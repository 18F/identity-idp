class OtpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    @success = valid_direct_otp_code?

    result
  end

  private

  attr_reader :code, :user, :success

  def valid_direct_otp_code?
    user.authenticate_direct_otp(code)
  end

  def result
    {
      success: success
    }
  end
end
