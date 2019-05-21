RequestPasswordReset = Struct.new(:email, :request_id) do
  def perform
    if user_not_found?
      form = RegisterUserEmailForm.new
      result = form.submit({ email: email }, instructions)
      [form.user, result]
    else
      user.send_reset_password_instructions
      nil
    end
  end

  private

  def instructions
    I18n.t('user_mailer.email_confirmation_instructions.first_sentence.forgot_password')
  end

  def user_not_found?
    user.is_a?(NonexistentUser)
  end

  def user
    @_user ||= User.find_with_email(email) || NonexistentUser.new
  end
end
