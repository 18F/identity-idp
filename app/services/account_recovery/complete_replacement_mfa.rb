# frozen_string_literal: true

module AccountRecovery
  class CompleteReplacementMfa
    attr_reader :removed_mfa_method_counts

    def initialize(account_recovery_request:)
      @account_recovery_request = account_recovery_request
      @removed_mfa_method_counts = {}
    end

    # @return [Boolean] whether the request was completed
    def call
      account_recovery_request.with_lock do
        return false unless account_recovery_request.replacement_mfa_pending?

        removed_counts = destroy_suspended_configurations

        completed = account_recovery_request.transition_to!(AccountRecoveryRequest::COMPLETED)
        @removed_mfa_method_counts = removed_counts if completed
        completed
      end
    end

    private

    attr_reader :account_recovery_request

    # @return [Hash{Symbol=>Integer}]
    def destroy_suspended_configurations
      counts = {}

      SuspendExistingMfa::CONFIGURATION_ASSOCIATIONS.each do |association|
        user.public_send(association)
          .where(account_recovery_request_id: account_recovery_request.id)
          .find_each do |configuration|
            friendly_name = configuration.friendly_name
            configuration.destroy!
            counts[friendly_name] = counts.fetch(friendly_name, 0) + 1
          end
      end

      counts
    end

    def user
      account_recovery_request.user
    end
  end
end
