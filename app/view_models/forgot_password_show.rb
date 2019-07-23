class ForgotPasswordShow
  attr_reader :resend, :session

  def initialize(resend:, session:)
    @resend = resend
    @session = session
  end

  def password_reset_email_form
    PasswordResetEmailForm.new(email)
  end

  def email
    @_email ||= session.delete(:email)
  end
end
