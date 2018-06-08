module UnconfirmedUserConcern
  def with_unconfirmed_user
    @confirmation_token = params[:confirmation_token]
    @user = User.find_or_initialize_with_error_by(:confirmation_token, @confirmation_token)
    @user = User.confirm_by_token(@confirmation_token) if @user.confirmed?
    @password_form = PasswordForm.new(@user)

    yield if block_given?
  end

  def validate_token
    with_unconfirmed_user do
      result = EmailConfirmationTokenValidator.new(@user).submit

      analytics.track_event(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, result.to_h)

      if result.success?
        process_successful_confirmation
      else
        process_unsuccessful_confirmation
      end
    end
  end

  def process_valid_confirmation_token
    @confirmation_token = params[:confirmation_token]
    @forbidden_passwords = ForbiddenPasswords.new(@user.email).call
    flash.now[:success] = t('devise.confirmations.confirmed_but_must_set_password')
    session[:user_confirmation_token] = @confirmation_token
  end

  def process_confirmed_user
    create_user_event(:email_changed, @user)

    flash[:success] = t('devise.confirmations.confirmed')
    redirect_to after_confirmation_url_for(@user)
    EmailNotifier.new(@user).send_email_changed_email
  end

  def after_confirmation_url_for(user)
    if !user_signed_in?
      new_user_session_url
    elsif user.two_factor_enabled?
      account_url
    else
      two_factor_options_url
    end
  end

  def process_unsuccessful_confirmation
    return process_already_confirmed_user if @user.confirmed?

    @confirmation_token = params[:confirmation_token]
    flash[:error] = unsuccessful_confirmation_error
    redirect_to sign_up_email_resend_url(request_id: params[:_request_id])
  end

  def process_already_confirmed_user
    action_text = t('devise.confirmations.sign_in') unless user_signed_in?
    flash[:error] = t('devise.confirmations.already_confirmed', action: action_text)

    redirect_to user_signed_in? ? account_url : new_user_session_url
  end

  def unsuccessful_confirmation_error
    if @user.confirmation_period_expired?
      @user.decorate.confirmation_period_expired_error
    else
      t('errors.messages.confirmation_invalid_token')
    end
  end
end
