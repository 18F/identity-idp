# Arguments:
#   * user_emails: String, comma-separated list of emails
#
# Usage:
#   ResetUserPasswordAndSendEmail.new(user_emails: 'test1t@test.com,test2@test.com').call

class ResetUserPasswordAndSendEmail
  def initialize(user_emails:)
    @user_emails = user_emails
  end

  def call
    reset_password_and_send_email_to_each_affected_user
  end

  private

  attr_reader :user_emails

  def reset_password_and_send_email_to_each_affected_user
    affected_emails.each do |email|
      user = User.find_with_email(email)
      if user
        ResetUserPassword.new(user: user).call
        UserMailer.please_reset_password(email).deliver_now
        Kernel.puts "Email sent to user with email #{email}"
      else
        Kernel.puts "user with email #{email} not found"
      end
    end
  end

  def affected_emails
    user_emails.split(',')
  end
end
