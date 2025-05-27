# frozen_string_literal: true

module Users
  class WebauthnPlatformRecommendedController < ApplicationController
    include SecureHeadersConcern

    before_action :confirm_two_factor_authenticated
    before_action :apply_secure_headers_override

    def new
      @sign_in_flow = session[:sign_in_flow]
      analytics.webauthn_platform_recommended_visited
    end

    def create
      analytics.webauthn_platform_recommended_submitted(opted_to_add: opted_to_add?)
      user_session[:webauthn_platform_recommended] = true if opted_to_add?
      current_user.update(webauthn_platform_recommended_dismissed_at: Time.zone.now)
      redirect_to dismiss_redirect_path
    end

    private

    def opted_to_add?
      params[:add_method].present?
    end

    def dismiss_redirect_path
      if opted_to_add?
        webauthn_setup_path(platform: true)
      else
        process_device_profiling_result
        after_mfa_setup_path
      end
    end
  end
end
