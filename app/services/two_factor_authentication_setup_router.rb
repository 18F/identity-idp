case @two_factor_options_form.selection.first
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
end