class TotpSetupForm
  def initialize(user, secret, code)
    @user = user
    @secret = secret
    @code = code
  end

  def submit
    @success = valid_totp_code?

    result
  end

  private

  attr_reader :user, :code, :secret, :success

  def valid_totp_code?
    user.confirm_totp_secret(secret, code)
  end

  def result
    {
      success: success
    }
  end
end
