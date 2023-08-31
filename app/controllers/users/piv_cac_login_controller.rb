module Users
  class PivCacLoginController < ApplicationController
    include PivCacConcern
    include VerifySpAttributesConcern
    include TwoFactorAuthenticatableMethods

    def new
      if params.key?(:token)
        process_piv_cac_login
      else
        render_prompt
      end
    end

    def redirect_to_piv_cac_service
      create_piv_cac_nonce
      redirect_to PivCacService.piv_cac_service_link(
        nonce: piv_cac_nonce,
        redirect_uri: login_piv_cac_url,
      ), allow_other_host: true
    end

    def account_not_found; end

    def did_not_work; end

    def temporary_error; end

    def error
      @presenter = PivCacErrorPresenter.new(
        error: params[:error],
        view: view_context,
        try_again_url: login_piv_cac_url,
      )
    end

    private

    def render_prompt
      analytics.piv_cac_setup_visit(in_account_creation_flow: false)
      @presenter = PivCacAuthenticationLoginPresenter.new(piv_cac_login_form, url_options)
      render :new
    end

    def process_piv_cac_login
      result = piv_cac_login_form.submit
      analytics.piv_cac_login(**result.to_h)
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
        piv_cac_required: sp_session[:piv_cac_requested],
      )
    end

    def process_valid_submission
      user = piv_cac_login_form.user
      sign_in(:user, user)

      mark_user_session_authenticated(:piv_cac)

      save_piv_cac_information(
        subject: piv_cac_login_form.x509_dn,
        issuer: piv_cac_login_form.x509_issuer,
        presented: true,
      )

      handle_valid_verification_for_authentication_context(
        auth_method: TwoFactorAuthenticatable::AuthMethod::PIV_CAC,
      )
      redirect_to next_step
    end

    def next_step
      if ial_context.ial2_requested?
        capture_password_url
      elsif !current_user.accepted_rules_of_use_still_valid?
        rules_of_use_path
      else
        after_sign_in_path_for(current_user)
      end
    end

    def ial_context
      @ial_context ||= IalContext.new(
        ial: sp_session_ial,
        service_provider: current_sp,
        user: piv_cac_login_form.user,
      )
    end

    def process_invalid_submission
      session[:needs_to_setup_piv_cac_after_sign_in] = true if piv_cac_login_form.valid_token?

      process_token_with_error
    end

    def process_token_with_error
      redirect_to login_piv_cac_error_url(error: piv_cac_login_form.error_type)
    end
  end
end
