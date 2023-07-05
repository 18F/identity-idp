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
    before_action :authorize_piv_cac_disable, only: :delete
    before_action :set_piv_cac_setup_csp_form_action_uris, only: :new
    before_action :cap_piv_cac_count, only: %i[new submit_new_piv_cac]
    before_action :confirm_recently_authenticated_2fa

    helper_method :in_multi_mfa_selection_flow?

    def new
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

    def delete
      analytics.user_registration_piv_cac_disabled
      remove_piv_cac
      clear_piv_cac_information
      create_user_event(:piv_cac_disabled)
      flash[:success] = t('notices.piv_cac_disabled')
      redirect_to account_two_factor_authentication_path
    end

    def submit_new_piv_cac
      if good_nickname
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
      mfa_user = MfaContext.new(current_user)
      analytics.user_registration_piv_cac_setup_visit(
        enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
      )
    end

    def remove_piv_cac
      revoke_remember_device(current_user)
      current_user_id = current_user.id
      Db::PivCacConfiguration.delete(current_user_id, params[:id].to_i)
      event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
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
      result = user_piv_cac_form.submit
      properties = result.to_h.merge(analytics_properties)
      analytics.multi_factor_auth_setup(**properties)
      irs_attempts_api_tracker.mfa_enroll_piv_cac(
        success: result.success?,
        subject_dn: user_piv_cac_form.x509_dn,
        failure_reason: irs_attempts_api_tracker.parse_failure_reason(result),
      )
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
      session[:needs_to_setup_piv_cac_after_sign_in] = false
      final_path = after_sign_in_path_for(current_user)
      redirect_to next_setup_path || final_path
    end

    def track_mfa_method_added
      mfa_user = MfaContext.new(current_user)
      analytics.multi_factor_auth_added_piv_cac(
        enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
      )
      Funnel::Registration::AddMfa.call(current_user.id, 'piv_cac', analytics)
    end

    def piv_cac_enabled?
      TwoFactorAuthentication::PivCacPolicy.new(current_user).enabled?
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

    def authorize_piv_cac_disable
      return if piv_cac_enabled? && MfaPolicy.new(current_user).multiple_factors_enabled?
      redirect_to account_two_factor_authentication_path
    end

    def good_nickname
      name = params[:name]
      name.present? && !PivCacConfiguration.exists?(user_id: current_user.id, name: name)
    end

    def analytics_properties
      {
        in_multi_mfa_selection_flow: in_multi_mfa_selection_flow?,
        enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
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
