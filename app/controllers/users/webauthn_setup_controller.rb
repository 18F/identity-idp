module Users
  class WebauthnSetupController < ApplicationController
    include MfaSetupConcern
    include RememberDeviceConcern
    include SecureHeadersConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :apply_secure_headers_override
    before_action :set_webauthn_setup_presenter

    def new
      form = WebauthnVisitForm.new
      result = form.submit(new_params)
      @platform_authenticator = form.platform_authenticator?
      @presenter = WebauthnSetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
        platform_authenticator: @platform_authenticator,
      )
      analytics.track_event(Analytics::WEBAUTHN_SETUP_VISIT, result.to_h)
      save_challenge_in_session
      @exclude_credentials = exclude_credentials
      flash_error(result.errors) unless result.success?
    end

    def confirm
      form = WebauthnSetupForm.new(current_user, user_session)
      result = form.submit(request.protocol, confirm_params)
      @platform_authenticator = form.platform_authenticator?
      @presenter = WebauthnSetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie: user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
        platform_authenticator: @platform_authenticator,
      )
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_SETUP, result.to_h)
      if result.success?
        process_valid_webauthn(form)
      else
        process_invalid_webauthn(form)
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

    def set_webauthn_setup_presenter
      @presenter = SetupPresenter.new(
        current_user: current_user,
        user_fully_authenticated: user_fully_authenticated?,
        user_opted_remember_device_cookie:
                                                  user_opted_remember_device_cookie,
        remember_device_default: remember_device_default,
      )
    end

    def user_opted_remember_device_cookie
      cookies.encrypted[:user_opted_remember_device_preference]
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
      counts_hash = MfaContext.new(current_user.reload).enabled_two_factor_configuration_counts_hash
      analytics.track_event(
        Analytics::WEBAUTHN_DELETED,
        success: success,
        mfa_method_counts: counts_hash,
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
      )
    end

    def save_challenge_in_session
      credential_creation_options = WebAuthn::Credential.options_for_create(user: current_user)
      user_session[:webauthn_challenge] = credential_creation_options.challenge.bytes.to_a
    end

    def process_valid_webauthn(form)
      create_user_event(:webauthn_key_added)
      mark_user_as_fully_authenticated
      handle_remember_device
      Funnel::Registration::AddMfa.call(current_user.id, 'webauthn')
      if form.platform_authenticator?
        flash[:success] = t('notices.webauthn_platform_configured')
      else
        flash[:success] = t('notices.webauthn_configured')
      end
      user_session[:auth_method] = 'webauthn'

      redirect_to user_next_authentication_setup_path!(after_mfa_setup_path)
    end

    def handle_remember_device
      save_user_opted_remember_device_pref
      save_remember_device_preference
    end

    def process_invalid_webauthn(form)
      if form.name_taken
        if form.platform_authenticator?
          flash.now[:error] = t('errors.webauthn_platform_setup.unique_name')
        else
          flash.now[:error] = t('errors.webauthn_setup.unique_name')
        end

        render :new
      else
        if form.platform_authenticator?
          flash[:error] = t('errors.webauthn_platform_setup.general_error')
        else
          flash[:error] = t('errors.webauthn_setup.general_error')
        end

        redirect_to account_two_factor_authentication_path
      end
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def new_params
      params.permit(:platform, :error)
    end

    def confirm_params
      params.permit(:attestation_object, :client_data_json, :name, :platform_authenticator)
    end

    def delete_params
      params.permit(:id)
    end
  end
end
