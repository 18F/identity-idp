module Users
  class PivCacSetupFromSignInController < ApplicationController
    include PivCacConcern
    include SecureHeadersConcern

    before_action :confirm_two_factor_authenticated
    before_action :apply_secure_headers_override, only: :success
    before_action :set_piv_cac_setup_csp_form_action_uris, only: :prompt

    def prompt
      if params.key?(:token)
        process_piv_cac_setup
      else
        render_prompt
      end
    end

    def success; end

    def next
      redirect_to after_sign_in_path_for(current_user)
    end

    def decline
      session.delete(:needs_to_setup_piv_cac_after_sign_in)
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def render_prompt
      analytics.track_event(Analytics::USER_REGISTRATION_PIV_CAC_SETUP_VISIT)
      render :prompt
    end

    def process_piv_cac_setup
      result = user_piv_cac_form.submit
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_SETUP, result.to_h)
      if result.success?
        process_valid_submission
      else
        process_invalid_submission
      end
    end

    def user_piv_cac_form
      @user_piv_cac_form ||= UserPivCacSetupForm.new(
        user: current_user,
        token: params[:token],
        nonce: piv_cac_nonce,
        name: user_session[:piv_cac_nickname],
      )
    end

    def process_invalid_submission
      redirect_to login_piv_cac_error_url(error: user_piv_cac_form.error_type)
    end

    def process_valid_submission
      session.delete(:needs_to_setup_piv_cac_after_sign_in)
      save_piv_cac_information(
        subject: user_piv_cac_form.x509_dn,
        issuer: user_piv_cac_form.x509_issuer,
        presented: true,
      )
      create_user_event(:piv_cac_enabled)
      redirect_to login_add_piv_cac_success_url
    end
  end
end
