# frozen_string_literal: true

module EventSummarizer
  module VendorResultEvaluators
    class SocureKyc
      class << self
        # @param result [Hash{String => Object}] The result structure logged to Cloudwatch
        # @return [Hash{Symbol => String}] A Hash with a type and description keys.
        def evaluate_result(result)
          return successful_response if result['success'] == true
          return timeout_response if result['timeout'] == true

          return failure_response(result['reason_codes'])
        end

        private

        BULLET = "#{' ' * 17}- ".freeze

        def successful_response
          {
            type: :socure_kyc_success,
            description: 'Socure KYC call succeeded',
          }
        end

        def timeout_response
          {
            type: :socure_kyc_timeout,
            description: 'Socure KYC call timed out',
          }
        end

        def failure_response(reason_codes)
          return {
            type: :socure_kyc_failures,
            description: failure_description(reason_codes),
          }
        end

        def failure_description(reason_codes)
          reason_codes ?
          "Socure KYC request failed:#{failure_reason_codes(reason_codes)}" :
          'Socure KYC request failed: Without reason codes'
        end

        def failure_reason_codes(reason_codes)
          reason_codes.map do |code, reason|
            "\n#{BULLET}#{code}: #{reason}" if code.match?(/^R\d+/)
          end.join
        end
      end
    end
  end
end
