module PersonalKeyConcern
  delegate :active_profile, to: :current_user

  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::InvalidAuthenticityToken, with: :redirect_to_signin
  end

  def create_new_code
    configuration_manager.create_new_code(user_session)
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

  def configuration_manager
    @configuration_manager ||=
      TwoFactorAuthentication::PersonalKeyConfigurationManager.new(current_user)
  end
end
