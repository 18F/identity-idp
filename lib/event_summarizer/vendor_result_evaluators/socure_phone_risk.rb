# frozen_string_literal: true

require_relative 'socure'

module EventSummarizer
  module VendorResultEvaluators
    class SocurePhoneRisk < Socure
      class << self
        private

        # Socure can reject a phone without returning any R-prefixed reason code
        def failure_description(result)
          failed_checks = failed_checks(result)
          reason_code_details = reason_code_details(result)

          if failed_checks.any?
            "#{failure_message(result)}: #{failed_checks.join('; ')}#{reason_code_details}"
          elsif reason_code_details.empty?
            "#{failure_message(result)}: Without reason codes"
          else
            "#{failure_message(result)}:#{reason_code_details}"
          end
        end

        def failed_checks(result)
          vendor_result = result.dig('vendor', 'result') || {}

          [
            name_correlation_failure(vendor_result),
            phonerisk_failure(vendor_result),
            autofail_reason_code_failure(vendor_result),
          ].compact
        end

        def name_correlation_failure(vendor_result)
          return nil unless vendor_result['name_correlation_successful'] == false

          score = vendor_result.dig('name_phone_correlation', 'score')
          "Name-phone correlation failed#{score_suffix(score)}"
        end

        def phonerisk_failure(vendor_result)
          return nil unless vendor_result['phonerisk_successful'] == false

          score = vendor_result.dig('phonerisk', 'score')
          "Phone risk failed#{score_suffix(score)}"
        end

        def autofail_reason_code_failure(vendor_result)
          codes = vendor_result['autofail_reason_codes']
          return nil if codes.nil? || codes.empty?

          "Matched automatic-failure reason codes: #{codes.join(', ')}"
        end

        def score_suffix(score)
          score.nil? ? '' : " (score: #{score})"
        end

        def reason_code_details(result)
          details = failure_reason_codes(reason_codes(result))
          details.empty? ? '' : details
        end

        def reason_codes(result)
          result.dig('vendor', 'result', 'phonerisk', 'reason_codes')
        end

        def type
          'phonerisk'
        end

        def module_name
          'Phone Risk'
        end
      end
    end
  end
end
