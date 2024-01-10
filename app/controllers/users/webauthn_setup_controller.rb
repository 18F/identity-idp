module Users
  class WebauthnSetupController < ApplicationController
    include TwoFactorAuthenticatableMethods
    include MfaSetupConcern
    include SecureHeadersConcern
    include ReauthenticationRequiredConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :apply_secure_headers_override
    before_action :set_webauthn_setup_presenter
    before_action :confirm_recently_authenticated_2fa
    before_action :validate_existing_platform_authenticator

    helper_method :in_multi_mfa_selection_flow?

    def new
      form = WebauthnVisitForm.new(
        user: current_user,
        url_options: url_options,
        in_mfa_selection_flow: in_multi_mfa_selection_flow?,
      )
      result = form.submit(new_params)
      @platform_authenticator = form.platform_authenticator?
      @presenter = WebauthnSetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
        platform_authenticator: @platform_authenticator,
        url_options:,
      )
      analytics.webauthn_setup_visit(
        platform_authenticator: result.extra[:platform_authenticator],
        in_account_creation_flow: user_session[:in_account_creation_flow] || false,
        enabled_mfa_methods_count: result.extra[:enabled_mfa_methods_count],
      )
      save_challenge_in_session
      @exclude_credentials = exclude_credentials
      @need_to_set_up_additional_mfa = need_to_set_up_additional_mfa?
      if !result.success?
        if @platform_authenticator
          irs_attempts_api_tracker.mfa_enroll_webauthn_platform(success: false)
        else
          irs_attempts_api_tracker.mfa_enroll_webauthn_roaming(success: false)
        end
      end

      if result.errors.present?
        analytics.webauthn_setup_submitted(
          platform_authenticator: form.platform_authenticator?,
          errors: result.errors,
          success: false,
        )
      end

      flash_error(result.errors) unless result.success?
    end

    def confirm
      form = WebauthnSetupForm.new(
        user: current_user,
        user_session: user_session,
        device_name: DeviceName.from_user_agent(request.user_agent),
      )
      result = form.submit(request.protocol, confirm_params)
      @platform_authenticator = form.platform_authenticator?
      @presenter = WebauthnSetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
        platform_authenticator: @platform_authenticator,
        url_options:,
      )
      properties = result.to_h.merge(analytics_properties)
      analytics.multi_factor_auth_setup(**properties)

      if @platform_authenticator
        irs_attempts_api_tracker.mfa_enroll_webauthn_platform(success: result.success?)
      else
        irs_attempts_api_tracker.mfa_enroll_webauthn_roaming(success: result.success?)
      end

      if result.success?
        process_valid_webauthn(form)
      else
        flash.now[:error] = result.first_error_message
        render :new
      end
    end

    def delete
      if MfaPolicy.new(current_user).multiple_factors_enabled?
        handle_successful_delete
      else
        handle_failed_delete
      end
      redirect_to account_two_factor_authentication_path
    end

    def show_delete
      @webauthn = WebauthnConfiguration.where(
        user_id: current_user.id, id: delete_params[:id],
      ).first

      if @webauthn
        render 'users/webauthn_setup/delete'
      else
        flash[:error] = t('errors.general')
        redirect_back fallback_location: new_user_session_url, allow_other_host: false
      end
    end

    private

    def validate_existing_platform_authenticator
      if platform_authenticator? && in_account_creation_flow? &&
         current_user.webauthn_configurations.platform_authenticators.present?
        redirect_to authentication_methods_setup_path
     end
    end

    def platform_authenticator?
      params[:platform] == 'true'
    end

    def set_webauthn_setup_presenter
      @presenter = SetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
      )
    end

    def flash_error(errors)
      flash.now[:error] = errors.values.first.first
    end

    def exclude_credentials
      current_user.webauthn_configurations.map(&:credential_id)
    end

    def handle_successful_delete
      webauthn = WebauthnConfiguration.find_by(user_id: current_user.id, id: delete_params[:id])
      return unless webauthn

      create_user_event(:webauthn_key_removed)
      webauthn.destroy
      revoke_remember_device(current_user)
      event = PushNotification::RecoveryInformationChangedEvent.new(user: current_user)
      PushNotification::HttpPush.deliver(event)
      if webauthn.platform_authenticator
        flash[:success] = t('notices.webauthn_platform_deleted')
      else
        flash[:success] = t('notices.webauthn_deleted')
      end
      track_delete(true)
    end

    def handle_failed_delete
      track_delete(false)
    end

    def track_delete(success)
      analytics.webauthn_delete_submitted(success:, configuration_id: delete_params[:id])
    end

    def save_challenge_in_session
      credential_creation_options = WebAuthn::Credential.options_for_create(user: current_user)
      user_session[:webauthn_challenge] = credential_creation_options.challenge.bytes.to_a
    end

    def process_valid_webauthn(form)
      create_user_event(:webauthn_key_added)
      analytics.webauthn_setup_submitted(
        platform_authenticator: form.platform_authenticator?,
        success: true,
      )
      handle_remember_device_preference(params[:remember_device])
      if form.platform_authenticator?
        handle_valid_verification_for_confirmation_context(
          auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM,
        )
        Funnel::Registration::AddMfa.call(current_user.id, 'webauthn_platform', analytics)
        flash[:success] = t('notices.webauthn_platform_configured')
      else
        handle_valid_verification_for_confirmation_context(
          auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN,
        )
        Funnel::Registration::AddMfa.call(current_user.id, 'webauthn', analytics)
        flash[:success] = t('notices.webauthn_configured')
      end
      redirect_to next_setup_path || after_mfa_setup_path
    end

    def analytics_properties
      {
        in_account_creation_flow: user_session[:in_account_creation_flow] || false,
      }
    end

    def need_to_set_up_additional_mfa?
      return false unless @platform_authenticator
      in_multi_mfa_selection_flow? && mfa_selection_count < 2
    end
    
    def new_params
      params.permit(:platform, :error)
    end

    def confirm_params
      params.permit(
        :attestation_object,
        :authenticator_data_value,
        :client_data_json,
        :name,
        :platform_authenticator,
        :transports,
      )
    end

    def delete_params
      params.permit(:id)
    end
  end
end
