# frozen_string_literal: true

module TwoFactorAuthentication
  class TotpVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include NewDeviceConcern

    before_action :confirm_totp_enabled

    def show
      recaptcha_annotation = annotate_recaptcha(
        RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR,
      )
      analytics.multi_factor_auth_enter_totp_visit(context: context, recaptcha_annotation:)

      @presenter = presenter_for_two_factor_authentication_method
      return unless FeatureManagement.prefill_otp_codes?
      @code = ROTP::TOTP.new(
        current_user.auth_app_configurations.first.otp_secret_key,
        interval: IdentityConfig.store.totp_code_interval,
      ).now
    end

    def create
      result = TotpVerificationForm.new(current_user, params.require(:code).strip).submit

      handle_verification_for_authentication_context(
        result:,
        auth_method: TwoFactorAuthenticatable::AuthMethod::TOTP,
      )
      if result.success?
        handle_remember_device_preference(params[:remember_device])
        redirect_to after_sign_in_path_for(current_user)
      else
        handle_invalid_mfa(type: 'totp', context:)
      end
    end

    private

    def confirm_totp_enabled
      return if current_user.auth_app_configurations.any?

      redirect_to user_two_factor_authentication_url
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::AuthenticatorDeliveryPresenter.new(
        data: authenticator_view_data,
        view: view_context,
        service_provider: current_sp,
        remember_device_default: remember_device_default,
      )
    end

    def authenticator_view_data
      {
        two_factor_authentication_method: 'authenticator',
      }.merge(generic_data)
    end
  end
end
