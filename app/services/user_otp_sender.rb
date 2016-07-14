class UserOtpSender
  def initialize(user)
    @user = user
  end

  def send_otp
    return if @user.second_factor_locked?

    SmsSenderOtpJob.perform_later(@user.direct_otp, @user.mobile)
  end
end
