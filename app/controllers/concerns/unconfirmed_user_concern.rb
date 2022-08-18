module UnconfirmedUserConcern
  include ActionView::Helpers::DateHelper

  def find_user_with_confirmation_token
    @confirmation_token = params.permit(:confirmation_token)[:confirmation_token]
    @email_address = EmailAddress.find_with_confirmation_token(@confirmation_token)
    @user = @email_address&.user
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
    analytics.user_registration_email_confirmation(
      success: false,
      errors: { email: [t('errors.messages.already_confirmed')] },
      user_id: @user.uuid,
    )
    irs_attempts_api_tracker.user_registration_email_confirmation(
      email: @email_address.email,
      success: false,
      failure_reason: { email: [:already_confirmed] },
    )
  end

  def stop_if_invalid_token
    result = email_confirmation_token_validator.submit
    analytics.user_registration_email_confirmation(**result.to_h)
    irs_attempts_api_tracker.user_registration_email_confirmation(
      email: @email_address&.email,
      success: result.success?,
      failure_reason: result.to_h[:error_details],
    )
    return if result.success?
    process_unsuccessful_confirmation
  end

  def email_confirmation_token_validator
    @email_confirmation_token_validator ||= EmailConfirmationTokenValidator.
      new(@email_address, current_user)
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
    if email_confirmation_token_validator.confirmation_period_expired?
      t('errors.messages.confirmation_period_expired')
    else
      t('errors.messages.confirmation_invalid_token')
    end
  end
end
