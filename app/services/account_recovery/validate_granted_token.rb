# frozen_string_literal: true

module AccountRecovery
  # Validates a raw recovery link token submitted from the emailed magic link.
  #
  # Accepts an unexpired token until password verification consumes it, including
  # retries after link verification. The raw token is never returned in analytics.
  class ValidateGrantedToken
    TOKEN_MISSING = :token_missing
    TOKEN_INVALID = :token_invalid
    TOKEN_EXPIRED = :token_expired
    WRONG_STATE = :wrong_state

    # The matched request, available to callers after a successful #call.
    # @return [AccountRecoveryRequest, nil]
    attr_reader :account_recovery_request

    # @param token [String, nil] raw token from the emailed link
    def initialize(token:)
      @token = token
    end

    # @return [FormResponse]
    def call
      return failure(TOKEN_MISSING) if token.blank?

      request = AccountRecoveryRequest.active_for_token_fingerprint(
        TokenCreator.fingerprint(token),
      )

      return failure(TOKEN_INVALID) if request.blank?
      return failure(WRONG_STATE) unless [
        AccountRecoveryRequest::GRANTED,
        AccountRecoveryRequest::LINK_VERIFIED,
      ].include?(request.state)
      return failure(TOKEN_EXPIRED) if request.token_expired?

      @account_recovery_request = request

      FormResponse.new(
        success: true,
        extra: { recovery_state: request.state },
      )
    end

    private

    attr_reader :token

    # @param reason [Symbol] bounded, non-PII reason safe for analytics
    # @return [FormResponse]
    def failure(reason)
      FormResponse.new(
        success: false,
        errors: { base: [reason.to_s] },
        extra: { failure_reason: reason.to_s },
      )
    end
  end
end
