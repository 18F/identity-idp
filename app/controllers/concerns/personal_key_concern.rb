module PersonalKeyConcern
  delegate :active_profile, to: :current_user

  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::InvalidAuthenticityToken, with: :redirect_to_signin
  end

  def create_new_code
    if active_profile.present?
      Pii::ReEncryptor.new(user: current_user, user_session: user_session).perform
      active_profile.personal_key
    else
      PersonalKeyGenerator.new(current_user).create
    end
  end

  private

  def redirect_to_signin
    controller_info = "#{controller_path}##{action_name}"
    analytics.track_event(
      Analytics::INVALID_AUTHENTICITY_TOKEN,
      controller: controller_info,
      user_signed_in: user_signed_in?
    )
    sign_out
    flash[:alert] = t('errors.invalid_authenticity_token')
    redirect_to new_user_session_url
  end
end
