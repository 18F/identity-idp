# frozen_string_literal: true

module SignUp
  class WebauthnPlatformSetupController < ApplicationController
    include SecureHeadersConcern
    include MfaSetupConcern
    include TwoFactorAuthenticatableMethods
    include ThreatMetrixHelper
    include ThreatMetrixConcern
    include WebauthnSetupFormConcern

    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :apply_secure_headers_override
    before_action :override_csp_for_threat_metrix,
                  if: :account_creation_threatmetrix_bootstrap_needed?
    before_action :redirect_if_already_has_platform_authenticator

    def new
      analytics.webauthn_platform_signup_setup_ab_test_visited(
        passkey_upsell_bucket: passkey_upsell_bucket,
      )
      mark_passkey_prompt_seen
      return unless auto_passkey_prompt_bucket?

      prepare_webauthn_setup_form(
        platform_authenticator: true,
        auto_trigger: true,
        need_to_set_up_additional_mfa: false,
      )
      render 'users/webauthn_setup/new'
    end

    def create
      analytics.webauthn_platform_signup_setup_ab_test_submitted(
        passkey_upsell_bucket: passkey_upsell_bucket,
      )
      mark_passkey_prompt_seen
      user_session[:webauthn_platform_signup_setup_recommended] = true
      prepare_webauthn_setup_form(
        platform_authenticator: true,
        auto_trigger: false,
        need_to_set_up_additional_mfa: false,
      )
      render 'users/webauthn_setup/new'
    end

    private

    def redirect_if_already_has_platform_authenticator
      return unless current_user.webauthn_configurations.platform_authenticators.present?

      redirect_to authentication_methods_setup_path
    end

    def passkey_upsell_bucket
      @passkey_upsell_bucket ||= ab_test_bucket(:PASSKEY_UPSELL)
    end

    def auto_passkey_prompt_bucket?
      passkey_upsell_bucket == :auto_passkey_prompt
    end

    def mark_passkey_prompt_seen
      return unless passkey_upsell_bucket.present?

      user_session[:auto_passkey_prompted] = true
    end
  end
end
