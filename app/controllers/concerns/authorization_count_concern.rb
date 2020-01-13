module AuthorizationCountConcern
  extend ActiveSupport::Concern

  private

  def auth_count
    session[:sp_auth_count][sp_session[:request_id]]
  end

  def bump_auth_count
    session[:sp_auth_count] ||= {}
    case session[:sp_auth_count][sp_session[:request_id]]
    when nil
      session[:sp_auth_count][sp_session[:request_id]] = 1
    else
      session[:sp_auth_count][sp_session[:request_id]] += 1
    end
    puts "#{'~' * 20} Bump auth count for #{sp_session[:request_id]} to #{session[:sp_auth_count][sp_session[:request_id]]}"
  end

  def delete_auth_count(request_id)
    session[:sp_auth_count].delete request_id
  end
end