class ForgotPasswordShow
  def initialize(resend:, session:)
    @resend = resend
    @session = session
  end

  def resend_confirmation_partial
    if resend.present?
      'forgot_password/resend_alert'
    else
      'shared/null'
    end
  end

  def password_reset_email_form
    PasswordResetEmailForm.new(email)
  end

  def email
    @_email ||= session.delete(:email)
  end

  private

  attr_reader :resend, :session
end
