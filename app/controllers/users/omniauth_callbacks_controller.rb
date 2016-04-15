require 'omniauth_authorizer'

module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token

    def saml
      authorize :omniauth_callback, :saml?

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
      set_flash_message(:notice, :success)
    end

    def process_invalid_authorization
      set_flash_message(:alert, :failure, reason: 'Invalid email')
      redirect_to root_url
    end
  end
end
