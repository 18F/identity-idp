# frozen_string_literal: true

module Test
  # Development/test helper for the account-preserving MFA recovery flow.
  #
  # Routes are only constructed when IdentityConfig.store.enable_test_routes is
  # true (production pins it to false). Lets a developer skip the waiting period
  # and get at the emailed recovery link directly, rather than
  # waiting on the scheduled job and digging the tokens out of a mail preview.
  class AccountRecoveryController < ApplicationController
    layout 'no_card'

    DEV_FORCED = 'dev_forced'

    def index
      @requests = AccountRecoveryRequest.order(id: :desc).limit(25)
      @granted_links = flash[:granted_links]
    end

    # Grants a waiting request immediately, bypassing the waiting period, and
    # surfaces the raw recovery token so the link can be followed in the browser.
    def grant
      recovery_request = find_request
      return render_not_found if recovery_request.blank?

      result = AccountRecovery::GrantRequest.new(
        account_recovery_request: recovery_request,
      ).call

      if result.success?
        flash[:granted_links] = {
          'verify' => account_recovery_verify_url(token: result.token.raw),
        }
      else
        flash[:error] = "Could not grant request: #{result.failure_reason}"
      end

      redirect_to test_account_recovery_url
    end

    def cancel
      recovery_request = find_request
      return render_not_found if recovery_request.blank?

      recovery_request.cancel!(reason: DEV_FORCED)

      redirect_to test_account_recovery_url
    end

    def expire
      recovery_request = find_request
      return render_not_found if recovery_request.blank?

      recovery_request.expire!(reason: DEV_FORCED)

      redirect_to test_account_recovery_url
    end

    def destroy
      recovery_request = find_request
      return render_not_found if recovery_request.blank?

      recovery_request.destroy!

      redirect_to test_account_recovery_url
    end

    private

    def find_request
      AccountRecoveryRequest.find_by(id: params[:id])
    end
  end
end
