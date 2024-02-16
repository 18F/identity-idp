module MfaSetupConcern
  extend ActiveSupport::Concern

  def next_setup_path
    if suggest_second_mfa?
      auth_method_confirmation_url
    elsif next_setup_choice
      confirmation_path
    elsif user_session[:mfa_selections]
      track_user_registration_mfa_setup_complete_event
      user_session.delete(:mfa_selections)

      sign_up_completed_path
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
      backup_code_create_url
    end
  end

  def confirm_user_authenticated_for_2fa_setup
    authenticate_user!(force: true)
    return if user_fully_authenticated?
    return unless MfaPolicy.new(current_user).two_factor_enabled?
    redirect_to user_two_factor_authentication_url
  end

  def in_multi_mfa_selection_flow?
    return false unless user_session[:mfa_selections].present?
    mfa_selection_index < mfa_selection_count
  end

  def mfa_context
    @mfa_context ||= MfaContext.new(current_user)
  end

  def suggest_second_mfa?
    return false unless user_session[:mfa_selections]
    mfa_selection_count < 2 && mfa_context.enabled_mfa_methods_count < 2
  end

  def in_account_creation_flow?
    user_session[:in_account_creation_flow] || false
  end

  def mfa_selection_count
    user_session[:mfa_selections]&.count || 0
  end

  def mfa_selection_index
    user_session[:mfa_selection_index] || 0
  end

  def show_skip_additional_mfa_link?
    !(mfa_context.enabled_mfa_methods_count == 1 &&
       mfa_context.webauthn_platform_configurations.count == 1)
  end

  private

  def track_user_registration_mfa_setup_complete_event
    analytics.user_registration_mfa_setup_complete(
      mfa_method_counts: mfa_context.enabled_two_factor_configuration_counts_hash,
      in_account_creation_flow: user_session[:in_account_creation_flow] || false,
      enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
      pii_like_keypaths: [[:mfa_method_counts, :phone]],
      second_mfa_reminder_conversion: user_session.delete(:second_mfa_reminder_conversion),
      success: true,
    )
  end

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
