# frozen_string_literal: true

module AccountRecovery
  module FailureResponse
    private

    # @param reason [Symbol] bounded, non-PII reason safe for analytics
    # @param attribute [Symbol] error key; token failures use +base+
    # @return [FormResponse]
    def failure(reason, attribute: :base)
      FormResponse.new(
        success: false,
        errors: { attribute => [reason.to_s] },
        extra: { failure_reason: reason.to_s },
      )
    end
  end
end
