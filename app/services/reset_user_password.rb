class ResetUserPassword
  def initialize(user:)
    @user = user
  end

  def call
    reset_user_password_and_log_event
  end

  private

  attr_reader :user

  def reset_user_password_and_log_event
    user.update!(password: SecureRandom.hex(8))
    Kernel.puts "Password for user with email #{user.email_address.email} has been reset"
  end
end
