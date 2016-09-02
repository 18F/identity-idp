class UserOtpSender
  def initialize(user)
    @user = user
  end

  def send_otp(code, options = {})
    return if user_decorator.blocked_from_entering_2fa_code?

    phone_number = @user.phone
    if options[:otp_method] == :voice
      VoiceSenderOtpJob.perform_later(code, phone_number)
    else
      SmsSenderOtpJob.perform_later(code, phone_number)
    end
  end

  private

  def user_decorator
    @user_decorator ||= @user.decorate
  end
end
