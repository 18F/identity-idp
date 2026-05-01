# frozen_string_literal: true

module SignUp
  class WebauthnPlatformSetupController < ApplicationController
    include SecureHeadersConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :apply_secure_headers_override

    def new
      analytics.webauthn_platform_recommended_visited
    end

    def create
      # analytics
      if opted_to_add?
        user_session[:webauthn_platform_setup] = true
        redirect_to webauthn_setup_path(platform: true)
      else
        redirect_to authentication_methods_setup_url
      end
    end

    private

    def opted_to_add?
      params[:add_method].present?
    end
  end
end
