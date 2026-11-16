# frozen_string_literal: true

module AccountRecovery
  # Expires a request whose emailed recovery link lapsed without being used.
  #
  # Called on page load from the recovery entry points so the next thing a user
  # does is correct, rather than waiting for the daily expiration job. Expiring
  # the request clears the partial unique index on active requests, which is
  # what allows the user to start a new request.
  #
  # Link verification alone does not consume the token. Until the password is
  # verified too, its expiration still applies.
  class ReconcileRequest
    # @param account_recovery_request [AccountRecoveryRequest, nil]
    def initialize(account_recovery_request:)
      @account_recovery_request = account_recovery_request
    end

    # @return [Boolean] whether the request was expired
    def call(now: Time.current)
      return false if account_recovery_request.blank?

      account_recovery_request.with_lock do
        return false unless [
          AccountRecoveryRequest::GRANTED,
          AccountRecoveryRequest::LINK_VERIFIED,
        ].include?(account_recovery_request.state)
        expires_at = account_recovery_request.token_expires_at
        return false if expires_at.present? && expires_at > now

        account_recovery_request.expire!(
          reason: AccountRecoveryRequest::FAILURE_REASON_TOKEN_NOT_REDEEMED,
        )
      end
    end

    private

    attr_reader :account_recovery_request
  end
end
