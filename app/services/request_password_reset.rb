RequestPasswordReset = Struct.new(:email, :request_id) do
  def perform
    # For security purposes, we don't want to allow password
    # recovery via email for admin and tech support users.
    return if user_found_but_is_an_admin_or_tech?

    if user_not_found?
      UserMailer.account_does_not_exist(email, request_id).deliver_later
    else
      user.send_reset_password_instructions
    end
  end

  private

  def user_not_found?
    user.is_a?(NonexistentUser)
  end

  def user_found_but_is_an_admin_or_tech?
    user.admin? || user.tech?
  end

  def user
    @_user ||= User.find_with_email(email) || NonexistentUser.new
  end
end
