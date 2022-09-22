module TwoFactorAuthentication
  class PivCacVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include PivCacConcern

    before_action :confirm_piv_cac_enabled, only: :show
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :show

    def show
      analytics.multi_factor_auth_enter_piv_cac(**analytics_properties)
      if params[:token]
        process_token
      else
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

    private

    def process_token
      result = piv_cac_verification_form.submit
      analytics.track_mfa_submit_event(
        result.to_h.merge(analytics_properties),
      )
      irs_attempts_api_tracker.mfa_login_piv_cac(
        success: result.success?,
        subject_dn: piv_cac_verification_form.x509_dn,
        failure_reason: result.to_h[:error_details],
      )
      if result.success?
        handle_valid_piv_cac
      else
        handle_invalid_piv_cac
      end
    end

    def handle_valid_piv_cac
      clear_piv_cac_nonce
      save_piv_cac_information(
        subject: piv_cac_verification_form.x509_dn,
        issuer: piv_cac_verification_form.x509_issuer,
        presented: true,
      )

      handle_valid_otp_for_authentication_context
      redirect_to after_otp_verification_confirmation_url
      reset_otp_session_data
    end

    def handle_invalid_piv_cac
      clear_piv_cac_information
      handle_invalid_otp(context: context, type: 'piv_cac')
    end

    # This overrides the method in TwoFactorAuthenticatable so that we
    # redirect back to ourselves rather than rendering the :show template.
    # This removes the token from the address bar and preserves the error
    # in the flash.
    def render_show_after_invalid
      flash[:error] = flash.now[:error]
      redirect_to login_two_factor_piv_cac_url
    end

    def piv_cac_view_data
      {
        two_factor_authentication_method: two_factor_authentication_method,
        hide_fallback_question: service_provider_mfa_policy.piv_cac_required?,
        user_email: current_user.email_addresses.take.email,
      }.merge(generic_data)
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
      }
    end
  end
end
