class EventDisavowalController < ApplicationController
  before_action :validate_disavowed_event

  def new
    # Memoize the form for use in the views
    password_reset_from_disavowal_form
    result = FormResponse.new(
      success: true,
      extra: EventDisavowal::BuildDisavowedEventAnalyticsAttributes.call(disavowed_event),
    )
    analytics.event_disavowal(**result.to_h)
    @forbidden_passwords = forbidden_passwords
  end

  def create
    result = password_reset_from_disavowal_form.submit(password_reset_params)
    analytics.event_disavowal_password_reset(**result.to_h)
    if result.success?
      handle_successful_password_reset
    else
      @forbidden_passwords = forbidden_passwords
      render :new
    end
  end

  private

  def forbidden_passwords
    disavowed_event.user.email_addresses.flat_map do |email_address|
      ForbiddenPasswords.new(email_address.email).call
    end
  end

  def password_reset_from_disavowal_form
    @password_reset_from_disavowal_form ||= EventDisavowal::PasswordResetFromDisavowalForm.new(
      disavowed_event,
    )
  end

  def password_reset_params
    params.require(:event_disavowal_password_reset_from_disavowal_form).permit(:password)
  end

  def validate_disavowed_event
    result = EventDisavowal::ValidateDisavowedEvent.new(disavowed_event).call
    return if result.success?
    analytics.event_disavowal_token_invalid(**result.to_h)
    flash[:error] = (result.errors[:event] || result.errors.first.last).first
    redirect_to root_url
  end

  def handle_successful_password_reset
    EventDisavowal::DisavowEvent.new(disavowed_event).call
    flash[:info] = t('devise.passwords.updated_not_active') if is_flashing_format?
    redirect_to new_user_session_url
  end

  def disavowal_token
    @disavowal_token ||= params[:disavowal_token]
  end

  def disavowed_event
    return if disavowal_token.nil?
    @disavowed_event ||= EventDisavowal::FindDisavowedEvent.new(disavowal_token).call
  end
end
