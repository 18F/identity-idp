module MonitorUrlHelper
  def idp_reset_password_url
    "#{config.idp_signin_url}/users/password/new"
  end

  def idp_signup_url
    "#{config.idp_signin_url}/sign_up/enter_email"
  end
end
