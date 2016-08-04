class UserOtpSender
  def initialize(user)
    @user = user
  end

  def send_otp(code)
    return if user_decorator.blocked_from_entering_2fa_code?

    if @user.phone_sms_enabled?
      SmsSenderOtpJob.perform_later(code, phone_number)
    else
      VoiceSenderOtpJob.perform_later(code, phone_number)
    end
  end

  private

  def user_decorator
    @user_decorator ||= @user.decorate
  end

  def phone_number
    @user.phone
  end
end
