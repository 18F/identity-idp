module FullyAuthenticatable
  def delete_branded_experience
    ServiceProviderRequestProxy.delete(request_id)
    session.delete(:sp)
  end

  def request_id
    sp_session[:request_id]
  end
end
