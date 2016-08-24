module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token

    def saml
      return render_401 unless FeatureManagement.allow_third_party_auth?

      OmniauthAuthorizer.new(auth_hash, session).perform do |user, action|
        @user = user
        send(action)
      end
    end

    private

    def auth_hash
      request.env['omniauth.auth']
    end

    def process_valid_authorization
      sign_in_and_redirect @user
      flash[:notice] = t('devise.omniauth_callbacks.success')
    end

    def process_invalid_authorization
      flash[:alert] = t('devise.omniauth_callbacks.failure', reason: 'Invalid email')
      redirect_to root_url
    end
  end
end
