module TwoFactorAuthenticationHelper
  def route_user_to_right_path
    case user_session[:selected_mfa_options].first
    when 'voice', 'sms', 'phone'
      redirect_to phone_setup_url
    when 'auth_app'
      redirect_to authenticator_setup_url
    when 'piv_cac'
      redirect_to setup_piv_cac_url
    when 'webauthn'
      redirect_to webauthn_setup_url
    when 'webauthn_platform'
      redirect_to webauthn_setup_url(platform: true)
    when 'backup_code'
      redirect_to backup_code_setup_url
    else
      
    end
  end
end