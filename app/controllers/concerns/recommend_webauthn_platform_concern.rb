# frozen_string_literal: true

module RecommendWebauthnPlatformConcern
  def recommend_webauthn_platform_for_sms_user?
    device_supports_platform_authenticator_setup? && user_set_up_with_phone? && user_set_up_with_phone?
  end

  private

  def device_supports_platform_authenticator_setup?
    user_session[:platform_authenticator_available] == true
  end

  def in_account_creation_flow?
    user_session[:in_account_creation_flow] == true
  end

  def user_set_up_with_phone?
    user_session[:in_account_creation_flow] == true && MfaContext.new(current_user).enabled_mfa_methods_count == 1
  end
end
