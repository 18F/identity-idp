module UnconfirmedUserConcern
  def find_user_with_confirmation_token
    @confirmation_token = params[:confirmation_token]
    @user = User.find_or_initialize_with_error_by(:confirmation_token, @confirmation_token)
  end

  def confirm_user_needs_sign_up_confirmation
    return unless @user&.confirmed?
    process_already_confirmed_user
  end

  def process_already_confirmed_user
    track_user_already_confirmed_event
    action_text = t('devise.confirmations.sign_in') unless user_signed_in?
    flash[:error] = t('devise.confirmations.already_confirmed', action: action_text)
    redirect_to user_signed_in? ? account_url : new_user_session_url
  end

  def track_user_already_confirmed_event
    hash = {
      success: false,
      errors: { email: [t('errors.messages.already_confirmed')] },
      user_id: @user.uuid,
    }
    analytics.track_event(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, hash)
  end

  def validate_token
    result = EmailConfirmationTokenValidator.new(@user).submit

    analytics.track_event(Analytics::USER_REGISTRATION_EMAIL_CONFIRMATION, result.to_h)

    if result.success?
      process_successful_confirmation
    else
      process_unsuccessful_confirmation
    end
  end

  def process_valid_confirmation_token
    @confirmation_token = params[:confirmation_token]
    @forbidden_passwords = @user.email_addresses.flat_map do |email_address|
      ForbiddenPasswords.new(email_address.email).call
    end
    flash.now[:success] = t('devise.confirmations.confirmed_but_must_set_password')
    session[:user_confirmation_token] = @confirmation_token
  end

  def process_unsuccessful_confirmation
    @confirmation_token = params[:confirmation_token]
    flash[:error] = unsuccessful_confirmation_error
    redirect_to sign_up_email_resend_url(request_id: params[:_request_id])
  end

  def unsuccessful_confirmation_error
    if @user&.confirmation_period_expired?
      @user.decorate.confirmation_period_expired_error
    else
      t('errors.messages.confirmation_invalid_token')
    end
  end
end
