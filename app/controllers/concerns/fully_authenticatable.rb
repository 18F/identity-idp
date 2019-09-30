module FullyAuthenticatable
  def delete_branded_experience
    #TODO clara re-add
    # ServiceProviderRequest.from_uuid(request_id).delete
  end

  def request_id
    sp_session[:request_id]
  end
end
