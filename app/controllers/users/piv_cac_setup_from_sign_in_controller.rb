module Users
  class PivCacSetupFromSignInController < ApplicationController
    include PivCacConcern

    before_action :confirm_two_factor_authenticated

    def prompt
      if params.key?(:token)
        process_piv_cac_setup
      elsif flash[:error_type].present?
        render_error
      else
        render_prompt
      end
    end

    def success; end

    def next
      redirect_to after_sign_in_path_for(current_user)
    end

    def decline
      session.delete(:x509_dn)
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def render_error
      @presenter = PivCacAuthenticationSetupErrorPresenter.new(error: flash[:error_type])
      render :error
    end

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
          )
    end

    def process_valid_submission
      session.delete(:x509_dn)
      flash[:success] = t('notices.piv_cac_configured')
      save_piv_cac_information(
          subject: user_piv_cac_form.x509_dn,
          presented: true,
          )
      create_user_event(:piv_cac_enabled)
      redirect_to login_add_piv_cac_success_url
    end
  end
end
