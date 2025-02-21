# frozen_string_literal: true

module FullyAuthenticatable
  def delete_branded_experience(logout: false)
    ServiceProviderRequestProxy.delete(request_id)
    if session[:sp]
      session[:sp][:successful_handoff] = true

    end

    session[:sp] = {} if logout
    nil
  end

  def request_id
    sp_session[:request_id]
  end
end
