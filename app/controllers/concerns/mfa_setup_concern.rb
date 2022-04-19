module MfaSetupConcern
  extend ActiveSupport::Concern

  def user_next_authentication_setup_path(next_setup_choice)
    if user_session.dig(:selected_mfa_options, determine_next_mfa_selection).present? &&
       IdentityConfig.store.select_multiple_mfa_options
      auth_method_confirmation_url(next_setup_choice: next_setup_choice)
    else
      user_session.delete(:selected_mfa_options)
      user_session.delete(:mfa_selection_final_path)
      nil
    end
  end

  def determine_next_mfa_selection
    return unless user_session[:selected_mfa_options]
    current_session = user_session[:next_mfa_selection_choice]
    current_index = user_session[:selected_mfa_options].find_index(current_session) || 0
    current_index + 1
  end

  def confirmation_path(next_mfa_selection_choice)
    user_session[:next_mfa_selection_choice] = next_mfa_selection_choice
    case next_mfa_selection_choice
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
    end
  end

  def confirm_user_authenticated_for_2fa_setup
    authenticate_user!(force: true)
    return if user_fully_authenticated?
    return unless MfaPolicy.new(current_user).two_factor_enabled?
    redirect_to user_two_factor_authentication_url
  end
end
