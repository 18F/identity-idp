module MfaSetupConcern
  extend ActiveSupport::Concern

  def next_setup_path
    if user_needs_confirmation_screen?
      auth_method_confirmation_url
    elsif next_setup_choice
      confirmation_path
    else
      user_session.delete(:mfa_selections)
      nil
    end
  end

  def confirmation_path(next_mfa_selection_choice = nil)
    user_session[:next_mfa_selection_choice] = next_mfa_selection_choice || next_setup_choice
    case user_session[:next_mfa_selection_choice]
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
    suggest_second_mfa? &&
      IdentityConfig.store.select_multiple_mfa_options
  end

  def in_multi_mfa_selection_flow?
    return false unless user_session[:mfa_selections].present?
    mfa_selection_index < mfa_selection_count
  end

  def suggest_second_mfa?
    mfa_selection_count < 2 && MfaContext.new(current_user).enabled_mfa_methods_count < 2
  end

  def mfa_selection_count
    user_session[:mfa_selections]&.count || 0
  end

  def mfa_selection_index
    user_session[:mfa_selection_index] || 0
  end

  private

  def determine_next_mfa
    return unless user_session[:mfa_selections]
    current_setup_step = user_session[:next_mfa_selection_choice]
    current_index = user_session[:mfa_selections].find_index(current_setup_step) || 0
    user_session[:mfa_selection_index] = current_index
    current_index + 1
  end

  def next_setup_choice
    user_session.dig(
      :mfa_selections,
      determine_next_mfa,
    )
  end
end
