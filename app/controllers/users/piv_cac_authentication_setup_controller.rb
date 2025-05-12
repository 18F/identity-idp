# frozen_string_literal: true

module Users
  class PivCacAuthenticationSetupController < ApplicationController
    include TwoFactorAuthenticatableMethods
    include PivCacConcern
    include MfaSetupConcern
    include RememberDeviceConcern
    include SecureHeadersConcern
    include ReauthenticationRequiredConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :set_piv_cac_setup_csp_form_action_uris, only: :new
    before_action :cap_piv_cac_count, only: %i[new submit_new_piv_cac]
    before_action :confirm_recently_authenticated_2fa

    helper_method :in_multi_mfa_selection_flow?

    def new
      @piv_cac_required = service_provider_mfa_policy.piv_cac_required?

      if params.key?(:token)
        process_piv_cac_setup
      else
        track_piv_cac_setup_visit
        render_prompt
      end
    end

    def error
      @presenter = PivCacErrorPresenter.new(
        error: params[:error],
        view: view_context,
        try_again_url: setup_piv_cac_url,
      )
    end

    def submit_new_piv_cac
      if skip?
        user_session.delete(:add_piv_cac_after_2fa)
        redirect_to after_sign_in_path_for(current_user)
      elsif good_nickname?
        user_session[:piv_cac_nickname] = params[:name]
        create_piv_cac_nonce
        redirect_to piv_cac_service_url_with_redirect, allow_other_host: true
      else
        flash[:error] = I18n.t('errors.piv_cac_setup.unique_name')
        render_prompt
      end
    end

    private

    def track_piv_cac_setup_visit
      analytics.piv_cac_setup_visited(**analytics_properties)
    end

    def render_prompt
      @presenter = PivCacAuthenticationSetupPresenter.new(
        current_user, user_fully_authenticated?, user_piv_cac_form
      )
      render :new
    end

    def piv_cac_service_url_with_redirect
      PivCacService.piv_cac_service_link(
        nonce: piv_cac_nonce,
        redirect_uri: setup_piv_cac_url,
      )
    end

    def process_piv_cac_setup
      increment_mfa_selection_attempt_count(TwoFactorAuthenticatable::AuthMethod::PIV_CAC)
      result = user_piv_cac_form.submit
      properties = result.to_h.merge(analytics_properties)
      analytics.multi_factor_auth_setup(**properties)

      attempts_api_tracker.mfa_enrolled(
        success: result.success?,
        mfa_device_type: TwoFactorAuthenticatable::AuthMethod::PIV_CAC,
      )

      if result.success?
        process_valid_submission
        user_session.delete(:mfa_attempts)
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
        piv_cac_required: service_provider_mfa_policy.piv_cac_required?,
      )
    end

    def process_valid_submission
      handle_valid_verification_for_confirmation_context(
        auth_method: TwoFactorAuthenticatable::AuthMethod::PIV_CAC,
      )
      flash[:success] = t('notices.piv_cac_configured')
      save_piv_cac_information(
        subject: user_piv_cac_form.x509_dn,
        issuer: user_piv_cac_form.x509_issuer,
        presented: true,
      )
      create_user_event(:piv_cac_enabled)
      track_mfa_method_added
      user_session.delete(:add_piv_cac_after_2fa)
      session[:needs_to_setup_piv_cac_after_sign_in] = false
      redirect_to next_setup_path || after_sign_in_path_for(current_user)
    end

    def track_mfa_method_added
      analytics.multi_factor_auth_added_piv_cac(**analytics_properties)
      Funnel::Registration::AddMfa.call(current_user.id, 'piv_cac', analytics, threatmetrix_attrs)
    end

    def process_invalid_submission
      if user_piv_cac_form.name_taken
        flash.now[:error] = t('errors.piv_cac_setup.unique_name')
        render_prompt
      else
        clear_piv_cac_information
        redirect_to setup_piv_cac_error_url(error: user_piv_cac_form.error_type)
      end
    end

    def skip?
      params[:skip] == 'true'
    end

    def good_nickname?
      name = params[:name]
      name.present? && !PivCacConfiguration.exists?(user_id: current_user.id, name: name)
    end

    def analytics_properties
      {
        in_account_creation_flow: user_session[:in_account_creation_flow] || false,
        enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
        attempts: mfa_attempts_count,
      }
    end

    def cap_piv_cac_count
      return unless IdentityConfig.store.max_piv_cac_per_account <= current_cac_count
      redirect_to account_two_factor_authentication_path
    end

    def current_cac_count
      current_user.piv_cac_configurations.count
    end
  end
end
