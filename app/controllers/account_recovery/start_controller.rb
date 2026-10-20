# frozen_string_literal: true

module AccountRecovery
  class StartController < ApplicationController
    include TwoFactorAuthenticatable
    include AccountRecoveryConcern

    before_action :reconcile_lapsed_request
    before_action :redirect_pending_request
    before_action :confirm_eligible_for_account_recovery

    def show
      analytics.account_recovery_options_visit
      @waiting_period_interval = account_recovery_wait_period_interval
    end

    def create
      return handle_rate_limited if rate_limiter.limited?

      rate_limiter.increment!

      result = AccountRecovery::CreateRequest.new(
        user: current_user,
      ).call

      analytics.account_recovery_request(**result.to_h)

      if result.success?
        redirect_to account_recovery_pending_url
      else
        flash[:error] = t('errors.general')
        redirect_to login_two_factor_options_url
      end
    end

    private

    def redirect_pending_request
      return unless AccountRecoveryRequest.active_for_user(current_user)&.awaiting_link_redemption?

      redirect_to account_recovery_pending_status_url
    end

    # Expires a lapsed, unredeemed request before eligibility is evaluated, so
    # a stale request does not permanently block the user from requesting
    # recovery again.
    def reconcile_lapsed_request
      expired = AccountRecovery::ReconcileRequest.new(
        account_recovery_request: AccountRecoveryRequest.active_for_user(current_user),
      ).call

      analytics.account_recovery_expired(count: 1) if expired
    end

    def confirm_eligible_for_account_recovery
      eligible = AccountRecovery::EligibilityPolicy.new(user: current_user).eligible?

      analytics.account_recovery_eligibility_evaluated(eligible:)

      return if eligible

      flash[:error] = t('account_recovery.start.unavailable')
      redirect_to login_two_factor_options_url
    end

    def handle_rate_limited
      analytics.account_recovery_request(
        success: false,
        rate_limited: true,
      )

      flash[:error] = t('account_recovery.start.rate_limited')
      redirect_to account_recovery_start_url
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :account_recovery_request,
      )
    end
  end
end
