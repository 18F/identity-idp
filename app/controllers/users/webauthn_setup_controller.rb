module Users
  class WebauthnSetupController < ApplicationController
    include RememberDeviceConcern
    include MfaSetupConcern
    include RememberDeviceConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :set_webauthn_setup_presenter

    def new
      result = WebauthnVisitForm.new.submit(params)
      analytics.track_event(Analytics::WEBAUTHN_SETUP_VISIT, result.to_h)
      save_challenge_in_session
      @exclude_credentials = exclude_credentials
      flash_error(result.errors) unless result.success?
    end

    def confirm
      form = WebauthnSetupForm.new(current_user, user_session)
      result = form.submit(request.protocol, params)
      analytics.track_event(Analytics::MULTI_FACTOR_AUTH_SETUP, result.to_h)
      if result.success?
        process_valid_webauthn
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
      redirect_to account_url
    end

    def show_delete
      render 'users/webauthn_setup/delete'
    end

    private

    def set_webauthn_setup_presenter
      @presenter = SetupPresenter.new(current_user, user_fully_authenticated?)
    end

    def flash_error(errors)
      flash.now[:error] = errors.values.first.first
    end

    def exclude_credentials
      current_user.webauthn_configurations.map(&:credential_id)
    end

    def handle_successful_delete
      create_user_event(:webauthn_key_removed)
      WebauthnConfiguration.where(user_id: current_user.id, id: params[:id]).destroy_all
      revoke_remember_device(current_user)
      flash[:success] = t('notices.webauthn_deleted')
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
      )
    end

    def save_challenge_in_session
      credential_creation_options = ::WebAuthn.credential_creation_options
      user_session[:webauthn_challenge] = credential_creation_options[:challenge].bytes.to_a
    end

    def process_valid_webauthn
      create_user_event(:webauthn_key_added)
      mark_user_as_fully_authenticated
      save_remember_device_preference
      Funnel::Registration::AddMfa.call(current_user.id, 'webauthn')
      redirect_to two_2fa_setup
    end

    def process_invalid_webauthn(form)
      if form.name_taken
        flash.now[:error] = t('errors.webauthn_setup.unique_name')
        render :new
      else
        flash[:error] = t('errors.webauthn_setup.general_error')
        redirect_to account_url
      end
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end

    def user_already_has_a_personal_key?
      TwoFactorAuthentication::PersonalKeyPolicy.new(current_user).configured?
    end
  end
end
