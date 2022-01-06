module Users
  class AuthorizationConfirmationController < ApplicationController
    include AuthorizationCountConcern
    include SecureHeadersConcern

    before_action :ensure_sp_in_session_with_request_url, only: [:new, :create]
    before_action :bump_auth_count
    before_action :confirm_two_factor_authenticated
    before_action :apply_secure_headers_override, only: [:new]

    def new
      analytics.track_event(Analytics::AUTHENTICATION_CONFIRMATION)
      @sp = ServiceProvider.find_by(issuer: sp_session[:issuer])
      @email = EmailContext.new(current_user).last_sign_in_email_address.email
    end

    def create
      analytics.track_event(Analytics::AUTHENTICATION_CONFIRMATION_CONTINUE)
      redirect_to sp_session_request_url_with_updated_params
    end

    def destroy
      analytics.track_event(Analytics::AUTHENTICATION_CONFIRMATION_RESET)
      sign_out :user
      redirect_to new_user_session_url(request_id: sp_session[:request_id])
    end

    private

    def ensure_sp_in_session_with_request_url
      return if sp_session&.dig(:request_url)

      redirect_to account_url
    end
  end
end
