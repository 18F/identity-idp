module Users
  class PivCacLoginController < ApplicationController
    include PivCacConcern
    include VerifySPAttributesConcern
    include TwoFactorAuthenticatableMethods

    def new
      if params.key?(:token)
        process_piv_cac_login
      elsif flash[:error_type].present?
        render_error
      else
        render_prompt
      end
    end

    def redirect_to_piv_cac_service
      create_piv_cac_nonce
      redirect_to PivCacService.piv_cac_service_link(piv_cac_nonce)
    end

    private

    def two_factor_authentication_method
      'piv_cac'
    end

    def render_error
      @presenter = PivCacAuthenticationErrorPresenter.new(error: flash[:error_type])
      render :error
    end

    def render_prompt
      analytics.track_event(Analytics::USER_REGISTRATION_PIV_CAC_SETUP_VISIT)
      @presenter = PivCacAuthenticationLoginPresenter.new(piv_cac_login_form)
      render :new
    end

    def process_piv_cac_login
      result = piv_cac_login_form.submit
      analytics.track_event(Analytics::PIV_CAC_LOGIN, result.to_h)
      clear_piv_cac_information
      clear_piv_cac_nonce
      if result.success?
        process_valid_submission
      else
        process_invalid_submission
      end
    end

    def piv_cac_login_form
      @piv_cac_login_form ||= UserPivCacLoginForm.new(
        token: params[:token],
        nonce: piv_cac_nonce,
      )
    end

    def process_valid_submission
      user = piv_cac_login_form.user
      sign_in(:user, user)

      mark_user_session_authenticated(:piv_cac)

      save_piv_cac_information(
        subject: piv_cac_login_form.x509_dn,
        presented: true,
      )

      handle_valid_otp(next_step)
    end

    def next_step
      if request_is_ial2?
        capture_password_url
      else
        after_otp_verification_confirmation_url
      end
    end

    def request_is_ial2?
      request_ial == 2
    end

    def request_ial
      sp_session && sp_session_ial > 1 ? 2 : 1
    end

    def process_invalid_submission
      flash[:error_type] = piv_cac_login_form.error_type
      redirect_to root_url
    end

    def mark_user_session_authenticated(authentication_type)
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
      analytics.track_event(
        Analytics::USER_MARKED_AUTHED,
        authentication_type: authentication_type,
      )
    end
  end
end
