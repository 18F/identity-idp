module MfaSetupConcern
  extend ActiveSupport::Concern

  def next_setup_path
    if user_needs_confirmation_screen?
      auth_method_confirmation_url(next_setup_choice: next_setup_choice)
    else
      user_session.delete(:mfa_selections)
      nil
    end
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

  def user_needs_confirmation_screen?
    (next_setup_choice.present? || suggest_second_mfa?) &&
      IdentityConfig.store.select_multiple_mfa_options
  end

  def suggest_second_mfa?
    MfaContext.new(current_user).enabled_mfa_methods_count < 2
  end

  def current_mfa_selection_count
    user_session[:mfa_selections]&.count || 0
  end

  private

  def determine_next_mfa
    return unless user_session[:mfa_selections]
    current_setup_step = user_session[:next_mfa_selection_choice]
    current_index = user_session[:mfa_selections].find_index(current_setup_step) || 0
    current_index + 1
  end

  def next_setup_choice
    user_session.dig(
      :mfa_selections,
      determine_next_mfa,
    )
  end
end
