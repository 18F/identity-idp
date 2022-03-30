module TwoFactorAuthenticationHelper
  def user_next_authentication_setup_path(final_path)
    case user_session[:selected_mfa_options].shift
    when 'voice', 'sms', 'phone'
      phone_setup_url
    when 'auth_app'
      authenticator_setup_url
    when 'piv_cac'
      setup_piv_cac_url
    when 'webauthn'
      webauthn_setup_url
    when 'webauthn_platform'
      webauthn_setup_url(platform: true)
    when 'backup_code'
      backup_code_setup_url
    else
      final_path
    end
  end
end