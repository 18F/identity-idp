# frozen_string_literal: true

module Test
  # Development/test helper for the account-preserving MFA recovery flow.
  class AccountRecoveryController < ApplicationController
    layout 'no_card'
    def index
      @requests = AccountRecoveryRequest.order(id: :desc).limit(25)
      @granted_links = flash[:granted_links]
    end

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

      recovery_request.cancel!(reason: 'test')

      redirect_to test_account_recovery_url
    end

    def expire
      recovery_request = find_request
      return render_not_found if recovery_request.blank?

      recovery_request.expire!(reason: 'test')

      redirect_to test_account_recovery_url
    end

    def destroy
      recovery_request = find_request
      return render_not_found if recovery_request.blank?

      AccountRecovery::SuspendExistingMfa::CONFIGURATION_ASSOCIATIONS.each do |association|
        # rubocop:disable Rails/SkipsModelValidations
        recovery_request.user.public_send(association)
          .where(account_recovery_request_id: recovery_request.id)
          .update_all(account_recovery_request_id: nil)
        # rubocop:enable Rails/SkipsModelValidations
      end

      recovery_request.destroy!

      redirect_to test_account_recovery_url
    end

    private

    def find_request
      AccountRecoveryRequest.find_by(id: params[:id])
    end
  end
end
