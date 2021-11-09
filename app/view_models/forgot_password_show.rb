class ForgotPasswordShow
  attr_reader :resend, :email

  def initialize(resend:, email:)
    @resend = resend
    @email = email
  end

  def password_reset_email_form
    PasswordResetEmailForm.new(email)
  end
end
