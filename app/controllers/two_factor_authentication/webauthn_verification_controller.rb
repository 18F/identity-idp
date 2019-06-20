module TwoFactorAuthentication
  # The WebauthnVerificationController class is responsible webauthn verification at sign in
  class WebauthnVerificationController < ApplicationController
    include TwoFactorAuthenticatable

    before_action :confirm_webauthn_enabled, only: :show

    def show
      save_challenge_in_session
      @presenter = presenter_for_two_factor_authentication_method
    end

    def confirm
      result = form.submit(request.protocol, params)
      analytics.track_mfa_submit_event(
        result.to_h.merge(analytics_properties),
        ga_cookie_client_id,
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
      save_remember_device_preference
      redirect_to after_otp_verification_confirmation_url
      reset_otp_session_data
      user_session.delete(:mfa_device_remembered)
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
        data: { credential_ids: credential_ids },
      )
    end

    def save_challenge_in_session
      credential_creation_options = ::WebAuthn.credential_request_options
      user_session[:webauthn_challenge] = credential_creation_options[:challenge].bytes.to_a
    end

    def credential_ids
      MfaContext.new(current_user).webauthn_configurations.map(&:credential_id).join(',')
    end

    def analytics_properties
      {
        context: context,
        multi_factor_auth_method: 'webauthn',
      }
    end

    def form
      WebauthnVerificationForm.new(current_user, user_session)
    end
  end
end
