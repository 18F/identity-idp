# frozen_string_literal: true

module AuthorizationCountConcern
  extend ActiveSupport::Concern

  # :reek:DuplicateMethodCall
  def auth_count
    session[:sp_auth_count] ||= {}
    session[:sp_auth_count][sp_session[:request_id]]
  end

  # :reek:DuplicateMethodCall
  def auth_count=(value)
    session[:sp_auth_count] ||= {}
    session[:sp_auth_count][sp_session[:request_id]] = value
  end

  def bump_auth_count
    case auth_count
    when nil
      self.auth_count = 1
    else
      self.auth_count += 1
    end
  end

  def delete_auth_count(request_id)
    session[:sp_auth_count].delete request_id
  end
end
