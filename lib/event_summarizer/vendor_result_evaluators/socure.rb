# frozen_string_literal: true

module EventSummarizer
  module VendorResultEvaluators
    # Base class for socure vendor result evaluators. Child classes should implement the
    # module_name, type, and reason_code template methods.
    class Socure
      class << self
        # @param result [Hash{String => Object}] The result structure logged to Cloudwatch
        # @return [Hash{Symbol => String}] A Hash with a type and description keys.
        def evaluate_result(result)
          return successful_response if result['success'] == true
          return timeout_response if result['timeout'] == true

          return failure_response(result)
        end

        private

        BULLET = "#{' ' * 17}- ".freeze

        def successful_response
          response(
            type: :"socure_#{type}_success",
            description: "Socure #{module_name} call succeeded",
          )
        end

        def timeout_response
          response(
            type: :"socure_#{type}_timeout",
            description: "Socure #{module_name} call timed out",
          )
        end

        def failure_response(result)
          response(type: :"socure_#{type}_failures", description: failure_description(result))
        end

        def failure_description(result)
          failures = failure_reason_codes(reason_codes(result))

          failures.empty? ?
          "#{failure_message(result)}: Without reason codes" :
          "#{failure_message(result)}:#{failures}"
        end

        def failure_reason_codes(reason_codes)
          return [] if !reason_codes

          reason_codes.map do |code, reason|
            "\n#{BULLET}#{code}: #{reason}" if code.match?(/^R\d+/)
          end.join
        end

        def failure_message(_result)
          "Socure #{module_name} request failed"
        end

        def response(type:, description:)
          { type:, description: }
        end
      end
    end
  end
end
