class ResetUserPassword
  def initialize(user:, log_stdout: false)
    @user = user
    @log_stdout = log_stdout
  end

  def call
    reset_user_password_and_log_event
  end

  private

  attr_reader :user

  def reset_user_password_and_log_event
    user.update!(password: SecureRandom.hex(8))
    return unless @log_stdout
    Kernel.puts "Password for user with email #{user.email_addresses.take.email} has been reset"
  end
end
