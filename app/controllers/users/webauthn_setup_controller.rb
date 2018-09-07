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

    private

    def save_challenge_in_session
      credential_creation_options = ::WebAuthn.credential_creation_options
      user_session[:webauthn_challenge] = credential_creation_options[:challenge].bytes.to_a
    end

    def two_factor_enabled?
      current_user.two_factor_enabled?
    end

    def process_valid_webauthn(attestation_response)
      create_webauthn_configuration(attestation_response)
      flash[:success] = t('notices.webauthn_added')
      redirect_to account_url
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
      public_key = Base64.encode64(credential.public_key)
      id = Base64.encode64(credential.id)
      WebauthnConfiguration.create(user_id: current_user.id,
                                   credential_public_key: public_key,
                                   credential_id: id,
                                   name: params[:name])
    end
  end
end
