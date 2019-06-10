module FullyAuthenticatable
  def delete_branded_experience
    ServiceProviderRequest.from_uuid(request_id).delete
  end

  def request_id
    sp_session[:request_id]
  end
end
