# frozen_string_literal: true

module RecommendWebauthnPlatformConcern
  def recommend_webauthn_platform_for_sms_user?(bucket)
    # Only consider for A/B test if:
    # 1. Option would be offered for setup
    # 2. User is viewing content in English
    # 3. Other recommendations have not already been offered (e.g. PIV/CAC for federal emails)
    # 4. User selected to setup phone or authenticated with phone
    # 5. User has not already set up a platform authenticator
    return false if !device_supports_platform_authenticator_setup?
    return false if I18n.locale != :en
    return false if current_user.webauthn_platform_recommended_dismissed_at?
    return false if !user_set_up_or_authenticated_with_phone?
    return false if current_user.webauthn_configurations.platform_authenticators.present?
    ab_test_bucket(:RECOMMEND_WEBAUTHN_PLATFORM_FOR_SMS_USER) == bucket
  end

  private

  def device_supports_platform_authenticator_setup?
    user_session[:platform_authenticator_available] == true
  end

  def in_account_creation_flow?
    user_session[:in_account_creation_flow] == true
  end

  def user_set_up_or_authenticated_with_phone?
    if in_account_creation_flow?
      current_user.phone_configurations.any? do |phone_configuration|
        phone_configuration.mfa_enabled? && phone_configuration.delivery_preference == 'sms'
      end
    else
      auth_methods_session.auth_events.pluck(:auth_method).
        include?(TwoFactorAuthenticatable::AuthMethod::SMS)
    end
  end
end
