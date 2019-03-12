class ResetPasswordAndNotifyUser
  attr_reader :email_address, :message

  def initialize(email_address, message)
    @email_address = email_address
    @message = message
  end

  def call
    return warn("User '#{email_address}' does not exist") if user.blank?
    reset_user_password
    notify_user
  end

  private

  def user
    @user ||= User.find_with_email(email_address)
  end

  def reset_user_password
    user.update!(encrypted_password_digest: '')
  end

  def notify_user
    UserMailer.please_reset_password(email_address, message).deliver_now
  end
end
