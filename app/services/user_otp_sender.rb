class UserOtpSender
  def initialize(user)
    @user = user
  end

  def send_otp
    return delete_mobile_and_send_otp if otp_should_only_go_to_email?
    return send_otp_to_all_2fa_devices if @user.unconfirmed_mobile.blank?
    send_otp_to_unconfirmed_mobile
  end

  def otp_should_only_go_to_mobile?
    @user.unconfirmed_mobile.present? && @user.two_factor_enabled?
  end

  # This method is executed by the two_factor_authentication gem upon login
  # and logout. See https://git.io/vgRwz
  def reset_otp_state
    @user.update(unconfirmed_mobile: nil)
    @user.remove_second_factor_mobile_id if @user.mobile.blank?
  end

  private

  def send_otp_to_second_factor(second_factor_name)
    second_factor = SecondFactor.find_by_name(second_factor_name)
    second_factor.create_authorization(@user)
  end

  def generate_new_otp
    @user.update_columns(otp_secret_key: ROTP::Base32.random_base32)
  end

  def user_only_has_email_2fa?
    @user.second_factors.pluck(:name) == ['Email']
  end

  def otp_should_only_go_to_email?
    user_only_has_email_2fa? && !@user.two_factor_enabled?
  end

  def delete_mobile_and_send_otp
    @user.update(unconfirmed_mobile: nil)
    send_otp_to_second_factor('Email')
  end

  def send_otp_to_unconfirmed_mobile
    generate_new_otp
    send_otp_to_second_factor('Mobile')
  end

  def send_otp_to_all_2fa_devices
    @user.second_factors.each do |second_factor|
      second_factor.create_authorization(@user)
    end
  end
end
