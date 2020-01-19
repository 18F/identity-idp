module Users
  class AuthorizationConfirmationController < ApplicationController
    include AuthorizationCountConcern

    before_action :bump_auth_count

    def show
      @sp = ServiceProvider.find_by(issuer: sp_session[:issuer]) if sp_session
    end

    def update
      sign_out :user
      redirect_to new_user_session_url(request_id: sp_session[:request_id])
    end
  end
end
