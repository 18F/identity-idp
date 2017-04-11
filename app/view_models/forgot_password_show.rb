class ForgotPasswordShow
  def initialize(params:, session:)
    @params = params
    @session = session
  end

  def resend_confirmation_partial
    if params[:resend].present?
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

  attr_reader :params, :session
end
