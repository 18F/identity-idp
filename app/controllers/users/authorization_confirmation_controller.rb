module Users
  class AuthorizationConfirmationController < ApplicationController

    before_action :bump_auth_count

    def index
      @sp = ServiceProvider.find_by(issuer: sp_session[:issuer]) if sp_session
    end

    def update
      request_id = sp_session[:request_id]
      sign_out :user
      redirect_to new_user_session_url(request_id: request_id)
    end

    private

    def auth_count
      session[:sp_auth_count][sp_session[:request_id]]
    end

    def bump_auth_count
      session[:sp_auth_count] ||= {}
      case session[:sp_auth_count][sp_session[:request_id]]
      when nil
        session[:sp_auth_count][sp_session[:request_id]] = 2
      else
        session[:sp_auth_count][sp_session[:request_id]] += 1
      end
      puts "\n#{'*' * 20} Bump auth count for #{sp_session[:request_id]} to #{session[:sp_auth_count][sp_session[:request_id]]}\n"
    end

    def delete_auth_count(request_id)
      session[:sp_auth_count].delete request_id
    end
  end
end
