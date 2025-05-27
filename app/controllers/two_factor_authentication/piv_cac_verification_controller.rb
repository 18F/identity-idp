# frozen_string_literal: true

module TwoFactorAuthentication
  class PivCacVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include PivCacConcern
    include NewDeviceConcern

    before_action :confirm_piv_cac_enabled, only: :show
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :show

    def show
      if params[:token]
        process_token
      else
        recaptcha_annotation = annotate_recaptcha(
          RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR,
        )
        analytics.multi_factor_auth_enter_piv_cac(**analytics_properties, recaptcha_annotation:)
        @presenter = presenter_for_two_factor_authentication_method
      end
    end

    def redirect_to_piv_cac_service
      create_piv_cac_nonce
      redirect_to PivCacService.piv_cac_service_link(
        nonce: piv_cac_nonce,
        redirect_uri: login_two_factor_piv_cac_url,
      ), allow_other_host: true
    end

    def error
      @presenter = PivCacErrorPresenter.new(
        error: params[:error],
        view: view_context,
        try_again_url: login_two_factor_piv_cac_url,
      )
    end

    private

    def process_token
      result = piv_cac_verification_form.submit
      session[:sign_in_flow] = :sign_in

      handle_verification_for_authentication_context(
        result:,
        auth_method: TwoFactorAuthenticatable::AuthMethod::PIV_CAC,
        extra_analytics: analytics_properties,
      )

      if result.success?
        handle_valid_piv_cac
      else
        handle_invalid_piv_cac(piv_cac_verification_form.error_type)
      end
    end

    def handle_valid_piv_cac
      clear_piv_cac_nonce
      save_piv_cac_information(
        subject: piv_cac_verification_form.x509_dn,
        issuer: piv_cac_verification_form.x509_issuer,
        presented: true,
      )

      redirect_to after_sign_in_path_for(current_user)
    end

    def handle_invalid_piv_cac(error)
      clear_piv_cac_information
      update_invalid_user

      if current_user.locked_out?
        handle_second_factor_locked_user(type: 'piv_cac', context:)
      elsif redirect_for_piv_cac_mismatch_replacement?
        redirect_to login_two_factor_piv_cac_mismatch_url
      else
        redirect_to login_two_factor_piv_cac_error_url(error: error)
      end
    end

    def redirect_for_piv_cac_mismatch_replacement?
      piv_cac_verification_form.error_type == 'user.piv_cac_mismatch' &&
        UserSessionContext.authentication_context?(context) &&
        current_user.piv_cac_configurations.count < IdentityConfig.store.max_piv_cac_per_account
    end

    def piv_cac_view_data
      { two_factor_authentication_method: 'piv_cac' }.merge(generic_data)
    end

    def piv_cac_verification_form
      @piv_cac_verification_form ||= UserPivCacVerificationForm.new(
        user: current_user,
        token: params[:token],
        nonce: piv_cac_nonce,
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def confirm_piv_cac_enabled
      return if TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled?

      redirect_to user_two_factor_authentication_url
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::PivCacAuthenticationPresenter.new(
        view: view_context,
        data: piv_cac_view_data,
        service_provider: current_sp,
        remember_device_default: remember_device_default,
      )
    end

    def analytics_properties
      {
        context: context,
        multi_factor_auth_method: 'piv_cac',
        piv_cac_configuration_id: piv_cac_verification_form&.piv_cac_configuration&.id,
        new_device: new_device?,
      }
    end
  end
end
