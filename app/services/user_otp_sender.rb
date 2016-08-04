class UserOtpSender
  def initialize(user)
    @user = user
  end

  def send_otp(code)
    return if user_decorator.blocked_from_entering_2fa_code?

    SmsSenderOtpJob.perform_later(code, @user.mobile)
  end

  private

  def user_decorator
    @user_decorator ||= @user.decorate
  end
end
