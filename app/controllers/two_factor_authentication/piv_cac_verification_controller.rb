module TwoFactorAuthentication
  class PivCacVerificationController < ApplicationController
    include TwoFactorAuthenticatable
    include PivCacConcern

    before_action :confirm_piv_cac_enabled, only: :show
    before_action :reset_attempt_count_if_user_no_longer_locked_out, only: :show

    def show
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_ENTER_PIV_CAC, analytics_properties)
      if params[:token]
        process_token
      else
        @presenter = presenter_for_two_factor_authentication_method
      end
    end

    private

    def process_token
      result = piv_cac_verfication_form.submit
      analytics.track_mfa_submit_event(
        result.to_h.merge(analytics_properties),
        ga_cookie_client_id,
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
        subject: piv_cac_verfication_form.x509_dn,
        presented: true,
      )

      handle_valid_otp_for_authentication_context
      redirect_to next_step
      reset_otp_session_data
      user_session.delete(:mfa_device_remembered)
    end

    def next_step
      if MfaPolicy.new(current_user).sufficient_factors_enabled?
        after_otp_verification_confirmation_url
      else
        two_factor_options_success_url
      end
    end

    def handle_invalid_piv_cac
      clear_piv_cac_information
      handle_invalid_otp(type: 'piv_cac')
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
        user_email: current_user.email_addresses.take.email,
      }.merge(generic_data)
    end

    def piv_cac_verfication_form
      @piv_cac_verification_form ||= UserPivCacVerificationForm.new(
        user: current_user,
        token: params[:token],
        nonce: piv_cac_nonce,
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
