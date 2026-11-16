# frozen_string_literal: true

module AccountRecovery
  class VerifyPassword
    include FailureResponse

    INCORRECT_PASSWORD = :incorrect_password
    TOKEN_INVALID = :token_invalid
    TRANSITION_FAILED = :transition_failed

    # @param account_recovery_request [AccountRecoveryRequest] request the link resolved to
    # @param password [String, nil] password submitted for the request owner
    def initialize(account_recovery_request:, password:)
      @account_recovery_request = account_recovery_request
      @password = password
    end

    # @return [FormResponse] an incorrect password is reported under the
    def call
      return failure(INCORRECT_PASSWORD, attribute: :password) unless password_valid?

      account_recovery_request.with_lock do
        unless account_recovery_request.token_valid?
          next failure(TOKEN_INVALID)
        end

        transitioned = account_recovery_request.transition_to!(
          AccountRecoveryRequest::PASSWORD_VERIFIED,
          token_fingerprint: nil,
          token_expires_at: nil,
        )
        next failure(TRANSITION_FAILED) unless transitioned

        FormResponse.new(
          success: true,
          extra: { recovery_state: account_recovery_request.state },
        )
      end
    end

    private

    attr_reader :account_recovery_request, :password

    def password_valid?
      account_recovery_request.user.valid_password?(password)
    end
  end
end
