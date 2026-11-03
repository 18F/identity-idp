# frozen_string_literal: true

module AccountRecovery
  # Called only after a replacement credential has been verified. Deletes the
  # request's suspended set, never every credential on the account.
  class CompleteReplacementMfa
    def initialize(account_recovery_request:)
      @account_recovery_request = account_recovery_request
    end

    # @return [Boolean] whether the request was completed
    def call
      account_recovery_request.with_lock do
        return false unless account_recovery_request.replacement_mfa_pending?

        SuspendExistingMfa::CONFIGURATION_ASSOCIATIONS.each do |association|
          user.public_send(association)
            .where(account_recovery_request_id: account_recovery_request.id).find_each(&:destroy!)
        end
        account_recovery_request.transition_to!(AccountRecoveryRequest::COMPLETED)
      end
    end

    private

    attr_reader :account_recovery_request

    def user
      account_recovery_request.user
    end
  end
end
