module Users
  class WebauthnSetupController < ApplicationController
    include RememberDeviceConcern

    before_action :authenticate_user!
    before_action :confirm_two_factor_authenticated, if: :two_factor_enabled?

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

    def success
      @next_url = url_after_successful_webauthn_setup
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

    def flash_error(errors)
      flash.now[:error] = errors.values.first.first
    end

    def exclude_credentials
      current_user.webauthn_configurations.map(&:credential_id)
    end

    def handle_successful_delete
      create_user_event(:webauthn_key_removed)
      WebauthnConfiguration.where(user_id: current_user.id, id: params[:id]).destroy_all
      revoke_remember_device
      flash[:success] = t('notices.webauthn_deleted')
      track_delete(true)
    end

    def revoke_remember_device
      UpdateUser.new(
        user: current_user, attributes: { remember_device_revoked_at: Time.zone.now },
      ).call
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

    def two_factor_enabled?
      MfaPolicy.new(current_user).two_factor_enabled?
    end

    def process_valid_webauthn
      create_user_event(:webauthn_key_added)
      mark_user_as_fully_authenticated
      save_remember_device_preference
      redirect_to webauthn_setup_success_url
    end

    def url_after_successful_webauthn_setup
      return account_url if user_already_has_a_personal_key?

      policy = PersonalKeyForNewUserPolicy.new(user: current_user, session: session)
      return sign_up_personal_key_url if policy.show_personal_key_after_initial_2fa_setup?

      idv_jurisdiction_url
    end

    def process_invalid_webauthn(form)
      if form.name_taken
        flash.now[:error] = t('errors.webauthn_setup.unique_name')
        render 'users/webauthn_setup/new'
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
