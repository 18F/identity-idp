module TwoFactorAuthentication
  # The WebauthnVerificationController class is responsible webauthn verification at sign in
  class WebauthnVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :check_sp_required_mfa_bypass
    before_action :confirm_webauthn_enabled, only: :show

    def show
      save_challenge_in_session
      @presenter = presenter_for_two_factor_authentication_method
    end

    def confirm
      result = form.submit(request.protocol, params)
      analytics.track_mfa_submit_event(
        result.to_h.merge(analytics_properties),
      )
      handle_webauthn_result(result)
    end

    private

    def handle_webauthn_result(result)
      if result.success?
        handle_valid_webauthn
      else
        handle_invalid_webauthn
      end
    end

    def handle_valid_webauthn
      handle_valid_otp_for_authentication_context
      handle_remember_device
      redirect_to after_otp_verification_confirmation_url
      reset_otp_session_data
    end

    def handle_remember_device
      save_user_opted_remember_device_pref
      save_remember_device_preference
    end

    def two_factor_authentication_method
      'webauthn'
    end

    def handle_invalid_webauthn
      flash[:error] = t('errors.invalid_authenticity_token')
      redirect_to login_two_factor_webauthn_url
    end

    def confirm_webauthn_enabled
      return if TwoFactorAuthentication::WebauthnPolicy.new(current_user).enabled?

      redirect_to user_two_factor_authentication_url
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::WebauthnAuthenticationPresenter.new(
        view: view_context,
        data: { credential_ids: credential_ids,
                user_opted_remember_device_cookie: user_opted_remember_device_cookie },
        remember_device_default: remember_device_default,
        platform_authenticator: params[:platform],
      )
    end

    def user_opted_remember_device_cookie
      cookies.encrypted[:user_opted_remember_device_preference]
    end

    def save_challenge_in_session
      credential_creation_options = WebAuthn::Credential.options_for_get
      user_session[:webauthn_challenge] = credential_creation_options.challenge.bytes.to_a
    end

    def credential_ids
      MfaContext.new(current_user).webauthn_configurations.map(&:credential_id).join(',')
    end

    def analytics_properties
      {
        context: context,
        multi_factor_auth_method: 'webauthn',
        webauthn_configuration_id: form&.webauthn_configuration&.id,
      }
    end

    def form
      @form ||= WebauthnVerificationForm.new(current_user, user_session)
    end
  end
end
