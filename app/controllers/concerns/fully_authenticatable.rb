module FullyAuthenticatable
  def confirm_two_factor_authenticated(id = nil)
    return redirect_to sign_up_start_url(request_id: id) unless user_signed_in?

    return prompt_to_set_up_2fa unless current_user.mfa.two_factor_enabled?

    prompt_to_enter_otp
  end

  def delete_branded_experience
    ServiceProviderRequest.from_uuid(sp_session[:request_id]).delete
  end

  def request_id
    sp_session[:request_id]
  end
end
