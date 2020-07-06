module MonitorUrlHelper
  def lower_env
    ENV['LOWER_ENV']
  end

  def oidc_sp_url
    ENV["#{lower_env}_OIDC_SP_URL"]
  end

  def saml_sp_url
    ENV["#{lower_env}_SAML_SP_URL"]
  end

  def idp_signin_url
    ENV["#{lower_env}_IDP_URL"]
  end

  def idp_reset_password_url
    idp_signin_url.to_s + '/users/password/new'
  end
end
