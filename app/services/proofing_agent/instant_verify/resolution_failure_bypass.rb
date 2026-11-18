# frozen_string_literal: true

module ProofingAgent
  module InstantVerify
    # When LexisNexis Instant Verify fails only on checks we choose to bypass, treat the
    # resolution as successful. The original errors are left in place for analytics.
    class ResolutionFailureBypass
      attr_reader :resolution_result

      def initialize(resolution_result:)
        @resolution_result = resolution_result
      end

      def bypassable?
        return @bypassable if defined?(@bypassable)

        @bypassable = !resolution_result.success? &&
                      resolution_result.exception.blank? &&
                      bypass_error_code_checker.call
      end

      def bypassed_resolution_result
        return resolution_result unless bypassable?

        overridden_result(resolution_result)
      end

      private

      def bypass_error_code_checker
        Proofing::LexisNexis::InstantVerify::BypassErrorCodeChecker.new(
          errors: resolution_result.errors,
          bypass_error_codes:,
        )
      end

      def bypass_error_codes
        # reference CheckToAttributeMapper for mapping of failed checks to attributes
        IdentityConfig.store.ssa_instant_verify_bypass_error_codes.map(&:to_sym)
      end

      def overridden_result(result)
        Proofing::Resolution::Result.new(
          success: true,
          errors: result.errors,
          exception: result.exception,
          vendor_name: result.vendor_name,
          vendor_id: result.vendor_id,
          transaction_id: result.transaction_id,
          customer_user_id: result.customer_user_id,
          reference: result.reference,
          reason_codes: result.reason_codes,
          source_attribution: result.source_attribution,
          failed_result_can_pass_with_additional_verification:
            result.failed_result_can_pass_with_additional_verification,
          attributes_requiring_additional_verification:
            result.attributes_requiring_additional_verification,
          vendor_workflow: result.vendor_workflow,
          verified_attributes: result.verified_attributes,
        )
      end
    end
  end
end
