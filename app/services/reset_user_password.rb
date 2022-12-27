class ResetUserPassword
  def initialize(user:, remember_device_revoked_at: nil)
    @user = user
    @remember_device_revoked_at = remember_device_revoked_at
  end

  def call
    reset_user_password
    forget_all_browsers
    log_event
    notify_user
  end

  private

  attr_reader :user, :remember_device_revoked_at

  def reset_user_password
    user.update!(password: SecureRandom.hex(8))
  end

  def forget_all_browsers
    ForgetAllBrowsers.new(
      user,
      remember_device_revoked_at: remember_device_revoked_at,
    ).call
  end

  def log_event
    UserEventCreator.new(current_user: user).
      create_out_of_band_user_event(:password_invalidated)
  end

  def notify_user
    user.email_addresses.each do |email_address|
      UserMailer.with(user: user, email_address: email_address).please_reset_password.
        deliver_now_or_later
    end
  end
end
