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
      analytics.webauthn_platform_signup_setup_ab_test_submitted
      user_session[:webauthn_platform_signup_setup_recommended] = true
      redirect_to webauthn_setup_url(platform: true, auto_trigger: true)
    end
  end
end
