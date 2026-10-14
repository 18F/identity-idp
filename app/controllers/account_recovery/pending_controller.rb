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

    def show
      @waiting_period_interval = account_recovery_wait_period_interval
      @email = current_user.last_sign_in_email_address.email
    end

    private

    def confirm_account_recovery_request_exists
      render_not_found if account_recovery_request.blank?
    end

    def account_recovery_request
      @account_recovery_request ||= AccountRecoveryRequest.active_for_user(current_user)
    end
  end
end
