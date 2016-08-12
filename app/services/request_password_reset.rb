RequestPasswordReset = Struct.new(:email) do
  def perform
    if user_not_found? || user_found_but_is_an_admin_or_tech?
      # do nothing
      #
      # To prevent revealing account existence, we don't treat a
      # "user not found" scenario as an error, unlike Devise's default
      # behavior. That way, when the PasswordsController finishes processing
      # the action, it will look like a successful transaction. We act as if
      # the password reset email was sent, when in fact it wasn't.
      # Similary, for security purposes, we don't want to allow password
      # recovery via email for admin and tech support users.
    elsif user.confirmed?
      user.send_reset_password_instructions
    else
      # For a better UX, we resend the confirmation email instructions if the
      # account has not been confirmed yet.
      user.send_confirmation_instructions
    end
  end

  private

  def user_not_found?
    user.nil?
  end

  def user_found_but_is_an_admin_or_tech?
    user.admin? || user.tech?
  end

  def user
    @_user ||= User.find_by_email(email)
  end
end
