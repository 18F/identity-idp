# frozen_string_literal: true

module Idv
  module SocureErrorsConcern
    private

    def remaining_attempts
      RateLimiter.new(
        user: document_capture_session.user,
        rate_limit_type: :idv_doc_auth,
      ).remaining_count
    end

    def error_code_for(result)
      if result.errors[:unaccepted_id_type]
        :unaccepted_id_type
      elsif result.errors[:selfie_fail]
        :selfie_fail
      elsif result.errors[:socure]
        result.errors.dig(:socure, :reason_codes).first
      elsif result.errors[:network]
        :network
      elsif result.errors[:pii_validation]
        :pii_validation
      else
        # No error information available (shouldn't happen). Default
        # to :network if it does.
        :network
      end
    end
  end
end
