class UserOtpSender
  def initialize(user)
    @user = user
  end

  def send_otp
    return if user_decorator.blocked_from_entering_2fa_code?

    SmsSenderOtpJob.perform_later(@user.direct_otp, @user.mobile)
  end

  private

  def user_decorator
    @user_decorator ||= UserDecorator.new(@user)
  end
end
