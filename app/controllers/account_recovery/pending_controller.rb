# frozen_string_literal: true

module AccountRecovery
  class PendingController < ApplicationController
    include TwoFactorAuthenticatable
    include AccountRecoveryConcern

    before_action :reconcile_lapsed_request
    before_action :confirm_account_recovery_request_exists
    before_action :confirm_waiting_request, only: :resend

    def show
      analytics.account_recovery_pending_visit(recovery_state: account_recovery_request.state)
      @waiting_period_interval = account_recovery_wait_period_interval
      @email = current_user.last_sign_in_email_address.email
    end

    def status
      analytics.account_recovery_pending_status_visit(
        recovery_state: account_recovery_request.state,
      )
      @pending_presenter = AccountRecovery::PendingPresenter.new(account_recovery_request)
    end

    def resend
      if rate_limiter.limited?
        analytics.account_recovery_resend_request_email(success: false, rate_limited: true)
        flash[:error] = t('account_recovery.pending.resend_rate_limited')
      else
        rate_limiter.increment!
        UserMailer.with(user: current_user, email_address: current_user.last_sign_in_email_address)
          .account_recovery_request.deliver_now_or_later
        analytics.account_recovery_resend_request_email(success: true)
        flash[:success] = t('account_recovery.pending.resend_success')
      end

      redirect_to account_recovery_pending_url
    end

    # Cancellation is only available before the recovery link is verified.
    def cancel
      cancelled_request = account_recovery_request
      state_before_cancel = nil

      cancelled_request.with_lock do
        return render_not_found unless cancelled_request.awaiting_link_redemption?

        state_before_cancel = cancelled_request.state
        return render_not_found unless cancelled_request.cancel!(
          reason: AccountRecoveryRequest::CANCEL_REASON_USER_CANCELLED,
        )
      end

      analytics.account_recovery_cancelled(
        reason: AccountRecoveryRequest::CANCEL_REASON_USER_CANCELLED,
        recovery_state: state_before_cancel,
      )
      notify_user_of_cancellation

      flash[:success] = t('account_recovery.pending.cancel_success')
      redirect_to login_two_factor_options_url
    end

    private

    def confirm_waiting_request
      render_not_found unless account_recovery_request.state == AccountRecoveryRequest::WAITING
    end

    # Expires a request whose emailed link lapsed unused, so the user is not
    # held on this page waiting for a link that can no longer be redeemed and
    # can start a new request instead.
    def reconcile_lapsed_request
      return if account_recovery_request.blank?

      expired = AccountRecovery::ReconcileRequest.new(
        account_recovery_request: account_recovery_request,
      ).call

      return if !expired

      analytics.account_recovery_expired(count: 1)
      remove_instance_variable(:@account_recovery_request)
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :account_recovery_request,
      )
    end

    def notify_user_of_cancellation
      email_address = current_user.last_sign_in_email_address
      return if email_address.blank?

      UserMailer.with(user: current_user, email_address: email_address)
        .account_recovery_cancelled.deliver_now_or_later
    end

    def confirm_account_recovery_request_exists
      render_not_found unless account_recovery_request&.awaiting_link_redemption?
    end

    def account_recovery_request
      @account_recovery_request ||= AccountRecoveryRequest.active_for_user(current_user)
    end
  end
end
