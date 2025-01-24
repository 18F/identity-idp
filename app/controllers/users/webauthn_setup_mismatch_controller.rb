# frozen_string_literal: true

module Users
  class WebauthnSetupMismatchController < ApplicationController
    include MfaSetupConcern
    include MfaDeletionConcern
    include SecureHeadersConcern
    include ReauthenticationRequiredConcern

    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :apply_secure_headers_override
    before_action :confirm_recently_authenticated_2fa
    before_action :validate_session_mismatch_id

    def show
      analytics.webauthn_setup_mismatch_visited(
        configuration_id: configuration.id,
        platform_authenticator: platform_authenticator?,
      )

      @presenter = WebauthnSetupMismatchPresenter.new(configuration:)
    end

    def update
      analytics.webauthn_setup_mismatch_submitted(
        configuration_id: configuration.id,
        platform_authenticator: platform_authenticator?,
        confirmed_mismatch: true,
      )

      redirect_to next_setup_path || after_mfa_setup_path
    end

    def destroy
      result = ::TwoFactorAuthentication::WebauthnDeleteForm.new(
        user: current_user,
        configuration_id: webauthn_mismatch_id,
        skip_multiple_mfa_validation: in_multi_mfa_selection_flow?,
      ).submit

      analytics.webauthn_setup_mismatch_submitted(**result.to_h, confirmed_mismatch: false)

      if result.success?
        handle_successful_mfa_deletion(event_type: :webauthn_key_removed)
        redirect_to retry_setup_url
      else
        flash.now[:error] = result.first_error_message
        @presenter = WebauthnSetupMismatchPresenter.new(configuration:)
        render :show
      end
    end

    private

    def retry_setup_url
      # These are intentionally inverted: if the authenticator was set up as a platform
      # authenticator but was flagged as a mismatch, it implies that the user had originally
      # intended to add a security key.
      if platform_authenticator?
        webauthn_setup_url
      else
        webauthn_setup_url(platform: true)
      end
    end

    def webauthn_mismatch_id
      user_session[:webauthn_mismatch_id]
    end

    def configuration
      return @configuration if defined?(@configuration)
      @configuration = current_user.webauthn_configurations.find_by(id: webauthn_mismatch_id)
    end

    def validate_session_mismatch_id
      return if configuration.present?
      redirect_to next_setup_path || after_mfa_setup_path
    end

    delegate :platform_authenticator?, to: :configuration
  end
end
