# frozen_string_literal: true

module AccountRecoveryConcern
  extend ActiveSupport::Concern

  class_methods do
    # Setup pages are blocked during a password-only recovery session unless
    # the controller allows the action for replacement MFA enrollment.
    def allow_account_recovery_enrollment(only:)
      @account_recovery_enrollment_actions = Array(only).map(&:to_s)
    end

    def account_recovery_enrollment_actions
      @account_recovery_enrollment_actions || []
    end
  end

  def account_recovery_wait_period
    IdentityConfig.store.account_recovery_wait_period_days.days
  end

  def account_recovery_wait_period_interval
    WaitPeriodFormatter.call(account_recovery_wait_period)
  end

  def account_recovery_token_valid_period
    WaitPeriodFormatter.call(IdentityConfig.store.account_recovery_token_valid_for_hours.hours)
  end

  def replacement_mfa_pending?
    return false if current_user.blank? || current_user.is_a?(AnonymousUser)

    AccountRecoveryRequest.active_for_user(current_user)&.replacement_mfa_pending? || false
  end

  def recovery_enrollment_action?
    self.class.account_recovery_enrollment_actions.include?(action_name)
  end

  private

  # Recovery completes on the first verified replacement; any remaining
  # selections enroll as a normally authenticated user. Account creation
  # prompts (second MFA, passkey recommendation) do not apply here.
  def next_account_recovery_setup_path
    return confirmation_path if next_setup_choice

    user_session.delete(:account_recovery_completed)
    user_session.delete(:mfa_selections)
    user_session.delete(:next_mfa_selection_choice)
    flash[:success] = t('account_recovery.new_mfa_setup.completed_html')
    after_sign_in_path_for(current_user)
  end

  private

  def reconcile_lapsed_request
    recovery_request = AccountRecoveryRequest.active_for_user(current_user)
    return if recovery_request.blank?

    recovery_state = recovery_request.state
    expired = AccountRecovery::ReconcileRequest.new(
      account_recovery_request: recovery_request,
    ).call

    return unless expired

    analytics.account_recovery_expired(recovery_state:)
    @account_recovery_request = nil
  end

  def rate_limiter
    @rate_limiter ||= RateLimiter.new(
      user: current_user,
      rate_limit_type: :account_recovery_request,
    )
  end
end
