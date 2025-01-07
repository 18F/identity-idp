# frozen_string_literal: true

module TwoFactorAuthentication
  # The WebauthnVerificationController class is responsible webauthn verification at sign in
  class WebauthnVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include NewDeviceConcern

    before_action :confirm_webauthn_enabled, only: :show

    def show
      save_challenge_in_session
      analytics.multi_factor_auth_enter_webauthn_visit(**analytics_properties)
      @presenter = presenter_for_two_factor_authentication_method
    end

    def confirm
      result = form.submit
      handle_webauthn_result(result)
    end

    private

    def handle_webauthn_result(result)
      handle_verification_for_authentication_context(
        result:,
        auth_method:,
        extra_analytics: {
          **analytics_properties,
          multi_factor_auth_method_created_at:
            webauthn_configuration_or_latest.created_at.strftime('%s%L'),
        },
      )

      if result.success?
        handle_valid_webauthn
      else
        handle_invalid_webauthn(result)
      end
    end

    def handle_valid_webauthn
      handle_remember_device_preference(params[:remember_device])
      redirect_to after_sign_in_path_for(current_user)
    end

    def handle_invalid_webauthn(result)
      flash[:error] = result.first_error_message

      if platform_authenticator?
        redirect_to login_two_factor_webauthn_url(platform: 'true')
      else
        redirect_to login_two_factor_webauthn_url
      end
    end

    def auth_method
      if platform_authenticator?
        TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM
      else
        TwoFactorAuthenticatable::AuthMethod::WEBAUTHN
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
        platform_authenticator: platform_authenticator?,
      )
    end

    def save_challenge_in_session
      credential_creation_options = WebAuthn::Credential.options_for_get
      user_session[:webauthn_challenge] = credential_creation_options.challenge.bytes.to_a
    end

    def credentials
      webauthn_configurations
        .select { |configuration| configuration.platform_authenticator? == platform_authenticator? }
        .map do |configuration|
          { id: configuration.credential_id, transports: configuration.transports }
        end
    end

    def analytics_properties
      auth_method = if form&.webauthn_configuration&.platform_authenticator ||
                       platform_authenticator?
                      TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM
                    else
                      TwoFactorAuthenticatable::AuthMethod::WEBAUTHN
                    end
      {
        context: context,
        multi_factor_auth_method: auth_method,
        webauthn_configuration_id: form&.webauthn_configuration&.id,
        multi_factor_auth_method_created_at: form&.webauthn_configuration
          &.created_at&.strftime('%s%L'),
      }
    end

    def form
      @form ||= WebauthnVerificationForm.new(
        user: current_user,
        platform_authenticator: platform_authenticator_param?,
        url_options:,
        challenge: user_session[:webauthn_challenge],
        protocol: request.protocol,
        authenticator_data: params[:authenticator_data],
        client_data_json: params[:client_data_json],
        signature: params[:signature],
        credential_id: params[:credential_id],
        webauthn_error: params[:webauthn_error],
        screen_lock_error: params[:screen_lock_error],
      )
    end

    def platform_authenticator_param?
      params[:platform].to_s == 'true'
    end

    def platform_authenticator?
      if form.webauthn_configuration
        form.webauthn_configuration.platform_authenticator
      else
        platform_authenticator_param?
      end
    end

    def webauthn_configuration_or_latest
      form.webauthn_configuration || webauthn_configurations.first
    end

    def webauthn_configurations
      MfaContext.new(current_user).webauthn_configurations.order(created_at: :desc)
    end
  end
end
