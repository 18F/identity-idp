class TotpVerificationForm
  def initialize(user, code)
    @user = user
    @code = code
  end

  def submit
    @success = valid_totp_code?

    result
  end

  private

  attr_reader :user, :code, :success

  def valid_totp_code?
    user.authenticate_totp(code)
  end

  def result
    {
      success: success
    }
  end
end
