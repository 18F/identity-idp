module UnconfirmedUserConcern
  def with_unconfirmed_user
    token = params[:confirmation_token]
    @user = User.find_or_initialize_with_error_by(:confirmation_token, token)
    @user = User.confirm_by_token(token) if @user.confirmed?
    @password_form = PasswordForm.new(@user)

    yield
  end

  def after_confirmation_path_for(user)
    if !user_signed_in?
      new_user_session_url
    elsif user.two_factor_enabled?
      profile_path
    else
      phone_setup_url
    end
  end
end
