# frozen_string_literal: true

module SignUp
  class WebauthnPlatformSetupController < ApplicationController
    include SecureHeadersConcern

    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :apply_secure_headers_override

    def new
      analytics.webauthn_platform_signup_setup_ab_test_visited
    end

    def create
      analytics.webauthn_platform_signup_setup_ab_test_submitted(opted_to_add: opted_to_add?)
      if opted_to_add?
        user_session[:webauthn_platform_signup_setup_recommended] = true
      end
      redirect_to dismiss_redirect_path
    end

    private

    def opted_to_add?
      params[:add_webauthn_platform].present?
    end

    def dismiss_redirect_path
      if opted_to_add?
        webauthn_setup_path(platform: true, auto_trigger: true)
      else
        authentication_methods_setup_url
      end
    end
  end
end
