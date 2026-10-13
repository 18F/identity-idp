# frozen_string_literal: true

module AccountRecovery
  # Entry point for account-preserving MFA recovery.
  #
  # Reached only after successful password authentication, when the user reports
  # that they cannot access any configured MFA method. Eligible users are routed
  # here; everyone else falls back to the legacy destructive account reset.
  #
  # See docs/adr/0001-account-preserving-mfa-recovery.md.
  class StartController < ApplicationController
    include TwoFactorAuthenticatable
    include AccountRecoveryConcern

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
        requesting_issuer: sp_session[:issuer],
        bucket: treatment_bucket,
      ).call

      analytics.account_recovery_request(**result.to_h)

      if result.success?
        redirect_to account_recovery_pending_url
      else
        redirect_to account_reset_recovery_options_url
      end
    end

    private

    # Eligibility is authoritative on the server at every entry into the flow.
    # Ineligible users are sent to the legacy destructive account reset rather
    # than shown an error, matching the routing in the ADR.
    def confirm_eligible_for_account_recovery
      eligibility = AccountRecovery::EligibilityPolicy.new(
        user: current_user,
        bucket: treatment_bucket,
      ).call

      analytics.account_recovery_eligibility_evaluated(
        eligible: eligibility.eligible?,
        eligibility_reason: eligibility.reason,
      )

      return if eligibility.eligible?

      redirect_to account_reset_recovery_options_url
    end

    def handle_rate_limited
      analytics.account_recovery_request(
        success: false,
        eligibility_reason: AccountRecovery::EligibilityPolicy::ELIGIBLE,
        rate_limited: true,
      )

      redirect_to account_reset_recovery_options_url
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :account_recovery_request,
      )
    end
  end
end
