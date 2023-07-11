module TwoFactorAuthentication
  # The WebauthnVerificationController class is responsible webauthn verification at sign in
  class WebauthnVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :check_sp_required_mfa
    before_action :confirm_webauthn_enabled, only: :show

    def show
      save_challenge_in_session
      analytics.multi_factor_auth_enter_webauthn_visit(**analytics_properties)
      @presenter = presenter_for_two_factor_authentication_method
    end

    def confirm
      result = form.submit
      analytics.track_mfa_submit_event(
        result.to_h.merge(analytics_properties),
      )

      if analytics_properties[:multi_factor_auth_method] == 'webauthn_platform'
        irs_attempts_api_tracker.mfa_login_webauthn_platform(success: result.success?)
      elsif analytics_properties[:multi_factor_auth_method] == 'webauthn'
        irs_attempts_api_tracker.mfa_login_webauthn_roaming(success: result.success?)
      end

      handle_webauthn_result(result)
    end

    def error; end

    private

    def handle_webauthn_result(result)
      if result.success?
        handle_valid_webauthn
      else
        handle_invalid_webauthn
      end
    end

    def handle_valid_webauthn
      if form.webauthn_configuration.platform_authenticator
        handle_valid_verification_for_authentication_context(
          auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM,
        )
      else
        handle_valid_verification_for_authentication_context(
          auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN,
        )
      end
      handle_remember_device
      redirect_to after_sign_in_path_for(current_user)
    end

    def handle_invalid_webauthn
      is_platform_auth = params[:platform].to_s == 'true'
      if is_platform_auth
        flash[:error] = t(
          'two_factor_authentication.webauthn_error.multiple_methods',
          link: view_context.link_to(
            t('two_factor_authentication.webauthn_error.additional_methods_link'),
            login_two_factor_options_path,
          ),
        )
        redirect_to login_two_factor_webauthn_url(platform: 'true')
      else
        flash[:error] = t('errors.general')
        redirect_to login_two_factor_webauthn_url
      end
    end

    def confirm_webauthn_enabled
      return if TwoFactorAuthentication::WebauthnPolicy.new(current_user).enabled?

      redirect_to user_two_factor_authentication_url
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::WebauthnAuthenticationPresenter.new(
        view: view_context,
        data: { credentials:, user_opted_remember_device_cookie: },
        service_provider: current_sp,
        remember_device_default: remember_device_default,
        platform_authenticator: params[:platform].to_s == 'true',
      )
    end

    def save_challenge_in_session
      credential_creation_options = WebAuthn::Credential.options_for_get
      user_session[:webauthn_challenge] = credential_creation_options.challenge.bytes.to_a
    end

    def credentials
      MfaContext.new(current_user).webauthn_configurations.map do |configuration|
        { id: configuration.credential_id, transports: configuration.transports }
      end.to_json
    end

    def analytics_properties
      auth_method = if form&.webauthn_configuration&.platform_authenticator ||
                       params[:platform].to_s == 'true'
                      TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM
                    else
                      TwoFactorAuthenticatable::AuthMethod::WEBAUTHN
                    end
      {
        context: context,
        multi_factor_auth_method: auth_method,
        webauthn_configuration_id: form&.webauthn_configuration&.id,
        multi_factor_auth_method_created_at: form&.webauthn_configuration&.created_at,
      }
    end

    def form
      @form ||= WebauthnVerificationForm.new(
        user: current_user,
        challenge: user_session[:webauthn_challenge],
        protocol: request.protocol,
        authenticator_data: params[:authenticator_data],
        client_data_json: params[:client_data_json],
        signature: params[:signature],
        credential_id: params[:credential_id],
        webauthn_error: params[:webauthn_error],
      )
    end

    def check_sp_required_mfa
      check_sp_required_mfa_bypass(auth_method: 'webauthn')
    end
  end
end
