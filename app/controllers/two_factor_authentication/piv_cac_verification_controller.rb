module TwoFactorAuthentication
  class PivCacVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include PivCacConcern

    before_action :confirm_piv_cac_enabled
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :show

    def show
      if params[:token]
        process_token
      else
        create_piv_cac_nonce
        @presenter = presenter_for_two_factor_authentication_method
      end
    end

    private

    def process_token
      result = piv_cac_verfication_form.submit
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH, result.to_h.merge(analytics_properties))
      if result.success?
        clear_piv_cac_nonce
        handle_valid_piv_cac
      else
        # create new nonce for retry
        create_piv_cac_nonce
        handle_invalid_otp(type: 'piv_cac')
      end
    end

    def handle_valid_piv_cac
      handle_valid_otp_for_authentication_context

      redirect_to after_otp_verification_confirmation_url
      reset_otp_session_data
    end

    def piv_cac_view_data
      {
        two_factor_authentication_method: two_factor_authentication_method,
        user_email: current_user.email,
        remember_device_available: false,
        totp_enabled: current_user.totp_enabled?,
        piv_cac_nonce: piv_cac_nonce,
      }.merge(generic_data)
    end

    def piv_cac_verfication_form
      @piv_cac_verification_form ||= UserPivCacVerificationForm.new(
        user: current_user,
        token: params[:token],
        nonce: piv_cac_nonce
      )
    end

    def confirm_piv_cac_enabled
      return if current_user.piv_cac_enabled?

      redirect_to user_two_factor_authentication_url
    end

    def presenter_for_two_factor_authentication_method
      TwoFactorAuthCode::PivCacAuthenticationPresenter.new(
        view: view_context,
        data: piv_cac_view_data
      )
    end

    def analytics_properties
      {
        context: context,
        multi_factor_auth_method: 'piv_cac',
      }
    end
  end
end
