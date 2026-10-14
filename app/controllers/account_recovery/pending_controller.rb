# frozen_string_literal: true

module AccountRecovery
  # Confirmation page shown after an account-preserving MFA recovery request is
  # created, while the request waits out the configured period.
  #
  # The initial request notification is sent by CreateRequest. Cancellation and
  # the emailed recovery link arrive in later phases.
  class PendingController < ApplicationController
    include TwoFactorAuthenticatable
    include AccountRecoveryConcern

    before_action :confirm_account_recovery_request_exists
    before_action :confirm_waiting_request, only: :resend

    def show
      @waiting_period_interval = account_recovery_wait_period_interval
      @email = current_user.last_sign_in_email_address.email
    end

    def resend
      if rate_limiter.limited?
        flash[:error] = t('account_recovery.pending.resend_rate_limited')
      else
        rate_limiter.increment!
        UserMailer.with(user: current_user, email_address: current_user.last_sign_in_email_address)
          .account_recovery_request.deliver_now_or_later
        flash[:success] = t('account_recovery.pending.resend_success')
      end

      redirect_to account_recovery_pending_url
    end

    private

    def confirm_waiting_request
      render_not_found unless account_recovery_request.state == AccountRecoveryRequest::WAITING
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :account_recovery_request,
      )
    end

    def confirm_account_recovery_request_exists
      render_not_found if account_recovery_request.blank?
    end

    def account_recovery_request
      @account_recovery_request ||= AccountRecoveryRequest.active_for_user(current_user)
    end
  end
end
