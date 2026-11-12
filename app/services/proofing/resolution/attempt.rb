# frozen_string_literal: true

module Proofing
  module Resolution
    # One resolution vendor request, paired with the vendor that produced it.
    #
    # +vendor+ is the orchestration key used to build proofers and evaluate vendor-specific policy.
    # +result.vendor_name+ is the vendor's own result identifier, which existing analytics and
    # support tooling already read. They are not interchangeable.
    class Attempt
      PII_LIKE_KEYPATHS = [
        [:proofing_results, :context, :stages, :resolution_attempts, :errors, :ssn],
        [:proofing_results, :context, :stages, :resolution_attempts, :errors, :zipcode],
        [:proofing_results, :context, :stages, :resolution_attempts, :reason_codes],
      ].freeze

      attr_reader :vendor, :result

      def initialize(vendor:, result:)
        @vendor = vendor
        @result = result
      end

      # @param attempt_number [Integer] one-based position in the executed chain
      def to_h(attempt_number:)
        result.to_h.merge(
          attempt: attempt_number,
          vendor:,
        )
      end
    end
  end
end
