class ResetUserPassword
  def initialize(user:)
    @user = user
  end

  def call
    reset_user_password
    log_event
    notify_user
  end

  private

  attr_reader :user

  def reset_user_password
    user.update!(password: SecureRandom.hex(8))
  end

  def log_event
    UserEventCreator.new(current_user: user).
      create_out_of_band_user_event(:password_invalidated)
  end

  def notify_user
    user.email_addresses.each do |email_address|
      UserMailer.please_reset_password(email_address.email).deliver_now
    end
  end
end
