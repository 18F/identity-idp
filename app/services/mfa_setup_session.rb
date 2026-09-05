# frozen_string_literal: true

# Wraps the Warden/Devise-backed `user_session` hash to encapsulate all state
# used to drive the multi-step MFA setup flow. Constructed the same way as
# AuthMethodsSession (`MfaSetupSession.new(user_session:)`) so it can be unit
# tested against a plain hash.
class MfaSetupSession
  attr_reader :user_session

  def initialize(user_session:)
    @user_session = user_session
  end

  def selections
    user_session[:mfa_selections]
  end

  def selections=(value)
    user_session[:mfa_selections] = value
  end

  def selections?
    selections.present?
  end

  def selection_count
    selections&.count || 0
  end

  def selection_index
    user_session[:mfa_selection_index] || 0
  end

  def next_selection_choice
    user_session[:next_mfa_selection_choice]
  end

  def next_selection_choice=(value)
    user_session[:next_mfa_selection_choice] = value
  end

  # Advances the flow: records the index of the current step and returns the
  # setup choice for the next step (or nil when there are no selections).
  def next_setup_choice
    return unless selections
    user_session.dig(:mfa_selections, advance_to_next_index)
  end

  def in_account_creation_flow?
    user_session[:in_account_creation_flow] || false
  end

  def platform_authenticator_available?
    user_session[:platform_authenticator_available] == true
  end

  def threatmetrix_session_id
    user_session[:sign_up_threatmetrix_session_id]
  end

  # Consumes the second MFA reminder conversion flag, returning its value and
  # removing it from the session.
  def take_second_mfa_reminder_conversion!
    user_session.delete(:second_mfa_reminder_conversion)
  end

  def clear_selections!
    user_session.delete(:mfa_selections)
  end

  private

  def advance_to_next_index
    current_setup_step = next_selection_choice
    current_index = selections.find_index(current_setup_step) || 0
    user_session[:mfa_selection_index] = current_index
    current_index + 1
  end
end
