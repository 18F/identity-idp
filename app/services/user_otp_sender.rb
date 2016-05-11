class UserOtpSender
  def initialize(user)
    @user = user
  end

  def send_otp
    return if @user.second_factor_locked?

    generate_new_otp if @user.unconfirmed_mobile.present?

    SmsSenderOtpJob.perform_later(@user)
  end

  # This method is executed by the two_factor_authentication gem upon login
  # and logout. See https://git.io/vgRwz
  def reset_otp_state
    @user.update(unconfirmed_mobile: nil)
  end

  private

  def generate_new_otp
    @user.update_columns(otp_secret_key: ROTP::Base32.random_base32)
  end
end
