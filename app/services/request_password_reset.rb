RequestPasswordReset = Struct.new(:email) do
  def perform
    # For security purposes, we don't want to allow password
    # recovery via email for admin and tech support users.
    return if user_not_found? || user_found_but_is_an_admin_or_tech?

    user.send_reset_password_instructions
  end

  private

  def user_not_found?
    user.nil?
  end

  def user_found_but_is_an_admin_or_tech?
    user.admin? || user.tech?
  end

  def user
    @_user ||= User.find_with_email(email)
  end
end
