# frozen_string_literal: true

module AccountRecovery
  # Grants a waiting account-preserving MFA recovery request: mints the
  # single-use recovery link token, then moves the request to the granted
  # state.
  #
  # The raw tokens are returned to the caller in memory only. Only keyed
  # fingerprint is persisted, so a database reader cannot reconstruct the link.
  class GrantRequest
    INELIGIBLE = :ineligible
    NOT_WAITING = :not_waiting
    TRANSITION_FAILED = :transition_failed

    Result = Struct.new(:success, :failure_reason, :token, keyword_init: true) do
      def success?
        !!success
      end
    end

    # @param account_recovery_request [AccountRecoveryRequest]
    def initialize(account_recovery_request:)
      @account_recovery_request = account_recovery_request
    end

    # @return [Result]
    def call
      account_recovery_request.with_lock do
        if account_recovery_request.state != AccountRecoveryRequest::WAITING
          return failure(NOT_WAITING)
        end

        return cancel_ineligible_request if !still_eligible?

        token = TokenCreator.call

        transitioned = account_recovery_request.transition_to!(
          AccountRecoveryRequest::GRANTED,
          token_fingerprint: token.fingerprint,
          token_expires_at: token.expires_at,
        )

        return failure(TRANSITION_FAILED) if !transitioned

        Result.new(success: true, token: token)
      end
    end

    private

    attr_reader :account_recovery_request

    def still_eligible?
      EligibilityPolicy.new(
        user: account_recovery_request.user,
        ignore_pending_request: account_recovery_request,
      ).eligible?
    end

    # A request that can no longer be granted is cancelled rather than left
    # waiting forever, which also frees the user to use another recovery path.
    def cancel_ineligible_request
      account_recovery_request.cancel!(
        reason: AccountRecoveryRequest::CANCEL_REASON_INELIGIBLE,
      )

      failure(INELIGIBLE)
    end

    # @param reason [Symbol] bounded, non-PII reason safe for analytics
    # @return [Result]
    def failure(reason)
      Result.new(success: false, failure_reason: reason)
    end
  end
end
