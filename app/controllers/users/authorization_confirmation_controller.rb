module Users
  class AuthorizationConfirmationController < ApplicationController
    include AuthorizationCountConcern
    include SecureHeadersConcern

    before_action :ensure_sp_in_session_with_request_url, only: [:new, :create]
    before_action :bump_auth_count
    before_action :confirm_two_factor_authenticated
    before_action :apply_secure_headers_override, only: [:new]

    def new
      analytics.authentication_confirmation
      @sp = ServiceProvider.find_by(issuer: sp_session[:issuer])
      @email = EmailContext.new(current_user).last_sign_in_email_address.email
    end

    def create
      analytics.authentication_confirmation_continue
      redirect_to sp_session_request_url_with_updated_params, allow_other_host: true
    end

    def destroy
      analytics.authentication_confirmation_reset
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
