module Users
  class WebauthnSetupController < ApplicationController
    before_action :authenticate_user!
    before_action :confirm_two_factor_authenticated, if: :two_factor_enabled?

    def new
      analytics.track_event(Analytics::WEBAUTHN_SETUP_VISIT)
      save_challenge_in_session
    end

    def confirm
      form = WebauthnSetupForm.new(current_user, user_session)
      result = form.submit(request.protocol, params)
      analytics.track_event(Analytics::WEBAUTHN_SETUP_SUBMITTED, result.to_h)
      if result.success?
        process_valid_webauthn(form.attestation_response)
      else
        process_invalid_webauthn(form)
      end
    end

    def delete
      if current_user.total_mfa_options_enabled > 1
        handle_successful_delete
      else
        handle_failed_delete
      end
      redirect_to account_url
    end

    private

    def handle_successful_delete
      WebauthnConfiguration.where(user_id: current_user.id, id: params[:id]).destroy_all
      flash[:success] = t('notices.webauthn_deleted')
      track_delete(true)
    end

    def handle_failed_delete
      flash[:error] = t('errors.webauthn_setup.delete_last')
      track_delete(false)
    end

    def track_delete(success)
      analytics.track_event(
        Analytics::WEBAUTHN_DELETED,
        success: success,
        mfa_options_enabled: current_user.total_mfa_options_enabled
      )
    end

    def save_challenge_in_session
      credential_creation_options = ::WebAuthn.credential_creation_options
      user_session[:webauthn_challenge] = credential_creation_options[:challenge].bytes.to_a
    end

    def two_factor_enabled?
      current_user.two_factor_enabled?
    end

    def process_valid_webauthn(attestation_response)
      mark_user_as_fully_authenticated
      create_webauthn_configuration(attestation_response)
      if current_user.decorate.should_acknowledge_personal_key?(user_session)
        redirect_to sign_up_personal_key_url
      else
        flash[:success] = t('notices.webauthn_added')
        redirect_to account_url
      end
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

    def create_webauthn_configuration(attestation_response)
      credential = attestation_response.credential
      public_key = Base64.strict_encode64(credential.public_key)
      id = Base64.strict_encode64(credential.id)
      WebauthnConfiguration.create(user_id: current_user.id,
                                   credential_public_key: public_key,
                                   credential_id: id,
                                   name: params[:name])
    end

    def mark_user_as_fully_authenticated
      user_session[TwoFactorAuthentication::NEED_AUTHENTICATION] = false
      user_session[:authn_at] = Time.zone.now
    end
  end
end
