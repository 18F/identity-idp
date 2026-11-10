# frozen_string_literal: true

module ProofingAgent
  module InstantVerify
    # When LexisNexis Instant Verify fails only on checks we choose to bypass, treat the
    # resolution as successful. The original errors are left in place for analytics.
    class ResolutionFailureBypass
      VENDOR_NAMES = [
        'lexisnexis:instant_verify',
        'lexisnexis:instant_verify_ddp',
      ].freeze

      ADJUDICATION_REASON = 'instant_verify_bypass'

      attr_reader :resolution_result

      def initialize(resolution_result:)
        @resolution_result = resolution_result
      end

      def bypassable?
        return false if resolution_stage.blank?

        resolution_stage[:success] != true &&
          VENDOR_NAMES.include?(resolution_stage[:vendor_name]) &&
          resolution_stage[:exception].blank? &&
          stages.dig(:residential_address, :success) != false &&
          BypassErrorCodeChecker.new(errors: resolution_stage[:errors]).call
      end

      # @return [Hash, nil] the original result unless the failure is bypassable
      def call
        return resolution_result unless bypassable?

        resolution_result.deep_merge(
          success: true,
          context: {
            resolution_adjudication_reason: ADJUDICATION_REASON,
            stages: { resolution: { success: true, bypassed: true } },
          },
        )
      end

      private

      def stages
        resolution_result&.dig(:context, :stages)
      end

      def resolution_stage
        stages&.dig(:resolution)
      end
    end
  end
end
