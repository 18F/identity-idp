# frozen_string_literal: true

module AccountRecovery
  class NewMfaSetupController < ApplicationController
    before_action :confirm_password_verified_request

    def show
      analytics.account_recovery_new_mfa_setup_visit(
        recovery_state: account_recovery_request.state,
      )
    end

    def create
      render_not_found
    end

    private

    def confirm_password_verified_request
      render_not_found if account_recovery_request.blank?
    end

    # confirms that the current request is associated with a password-verified
    def account_recovery_request
      return @account_recovery_request if defined?(@account_recovery_request)
      return if !user_signed_in? || user_fully_authenticated?

      @account_recovery_request = AccountRecoveryRequest.active.find_by(
        user: current_user,
        state: AccountRecoveryRequest::PASSWORD_VERIFIED,
      )
    end
  end
end
