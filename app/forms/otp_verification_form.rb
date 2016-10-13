class OtpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    @success = user.authenticate_direct_otp(code)

    result
  end

  private

  attr_reader :code, :user, :success

  def result
    {
      success?: success
    }
  end
end
