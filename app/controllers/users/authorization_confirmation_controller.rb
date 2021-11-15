module Users
  class AuthorizationConfirmationController < ApplicationController
    include AuthorizationCountConcern
    include SecureHeadersConcern

    before_action :ensure_sp_in_session_with_request_url, only: :show
    before_action :bump_auth_count
    before_action :confirm_two_factor_authenticated
    before_action :apply_secure_headers_override, only: [:show]

    def show
      analytics.track_event(Analytics::AUTHENTICATION_CONFIRMATION)
      @sp = ServiceProvider.find_by(issuer: sp_session[:issuer])
      @email = EmailContext.new(current_user).last_sign_in_email_address.email
    end

    def update
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
