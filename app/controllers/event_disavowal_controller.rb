class EventDisavowalController < ApplicationController
  before_action :validate_disavowed_event

  def new
    # Memoize the form for use in the views
    password_reset_from_disavowal_form
    analytics.track_event(
      Analytics::EVENT_DISAVOWAL,
      FormResponse.new(
        success: true,
        errors: {},
        extra: EventDisavowal::BuildDisavowedEventAnalyticsAttributes.call(disavowed_event),
      ).to_h,
    )
  end

  def create
    result = password_reset_from_disavowal_form.submit(password_reset_params)
    analytics.track_event(Analytics::EVENT_DISAVOWAL_PASSWORD_RESET, result.to_h)
    if result.success?
      handle_successful_password_reset
    else
      render :new
    end
  end

  private

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
    analytics.track_event(Analytics::EVENT_DISAVOWAL_TOKEN_INVALID, result.to_h)
    flash[:error] = result.errors[:event].first
    redirect_to root_url
  end

  def handle_successful_password_reset
    EventDisavowal::DisavowEvent.new(disavowed_event).call
    flash[:notice] = t('devise.passwords.updated_not_active') if is_flashing_format?
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
