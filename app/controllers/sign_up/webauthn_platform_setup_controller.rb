# frozen_string_literal: true

module SignUp
  class WebauthnPlatformSetupController < ApplicationController
    include SecureHeadersConcern
    include TwoFactorAuthenticatableMethods
    include MfaSetupConcern

    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :apply_secure_headers_override

    def new
      analytics.webauthn_platform_signup_setup_ab_test_visited
      save_challenge_in_session
      @exclude_credentials = exclude_credentials
      @presenter = SetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
      )
    end

    def confirm
      analytics.webauthn_platform_signup_setup_ab_test_submitted
      user_session[:webauthn_platform_signup_setup_recommended] = true

      form = WebauthnSetupForm.new(
        user: current_user,
        user_session: user_session,
        device_name: DeviceName.from_user_agent(request.user_agent),
      )

      result = form.submit(confirm_params)

      analytics.multi_factor_auth_setup(
        **result.to_h.merge(
          in_account_creation_flow: true,
          success: result.success?,
          multi_factor_auth_method: 'webauthn_platform',
        ),
      )

      if result.success?
        process_valid_webauthn(form)
        redirect_to authentication_methods_setup_path
      else
        flash[:error] = result.first_error_message
        redirect_to sign_up_webauthn_platform_setup_path(error: result.first_error_message)
      end
    end

    private

    def process_valid_webauthn(form)
      send_mfa_added_email(event_type: :webauthn_platform_added)
      analytics.webauthn_setup_submitted(
        platform_authenticator: true,
        in_account_creation_flow: true,
        success: true,
      )
      handle_remember_device_preference(params[:remember_device])
      handle_valid_verification_for_confirmation_context(
        auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM,
      )
      Funnel::Registration::AddMfa.call(
        current_user.id,
        'webauthn_platform',
        analytics,
        threatmetrix_attrs,
      )
      flash[:success] = t('notices.webauthn_platform_configured') if !form.transports_mismatch?
    end

    def confirm_params
      params.permit(
        :attestation_object,
        :authenticator_data_value,
        :client_data_json,
        :name,
        :platform_authenticator,
        :transports,
      ).merge(protocol: request.protocol)
    end

    def exclude_credentials
      current_user.webauthn_configurations.map(&:credential_id)
    end

    def save_challenge_in_session
      credential_creation_options = WebAuthn::Credential.options_for_get
      user_session[:webauthn_challenge] = credential_creation_options.challenge.bytes.to_a
    end
  end
end
