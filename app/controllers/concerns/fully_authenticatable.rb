module FullyAuthenticatable
  def delete_branded_experience(logout: false)
    ServiceProviderRequestProxy.delete(request_id)
    session[:sp] = {} if logout
    nil
  end

  def request_id
    sp_session[:request_id]
  end
end
