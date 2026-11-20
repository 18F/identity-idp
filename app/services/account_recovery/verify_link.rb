# frozen_string_literal: true

module AccountRecovery
  # Redeems an emailed recovery link.
  class VerifyLink
    include FailureResponse

    TOKEN_MISSING = :token_missing
    TOKEN_INVALID = :token_invalid
    TOKEN_EXPIRED = :token_expired
    TRANSITION_FAILED = :transition_failed

    attr_reader :account_recovery_request

    # @param token [String, nil] raw token from the emailed link or the session
    def initialize(token:)
      @token = token
    end

    # @return [FormResponse] on success, +recovery_state+ is the state before
    def call
      return failure(TOKEN_MISSING) if token.blank?

      request = AccountRecoveryRequest.active_for_token_fingerprint(
        TokenCreator.fingerprint(token),
      )

      return failure(TOKEN_INVALID) if request.blank?
      return failure(TOKEN_EXPIRED) if request.token_expired?

      recovery_state = request.state

      request.with_lock do
        next failure(TRANSITION_FAILED) unless link_verified?(request)

        @account_recovery_request = request
        FormResponse.new(success: true, extra: { recovery_state: })
      end
    end

    private

    attr_reader :token

    # @return [Boolean]
    def link_verified?(request)
      request.state == AccountRecoveryRequest::LINK_VERIFIED ||
        request.transition_to!(AccountRecoveryRequest::LINK_VERIFIED)
    end
  end
end
