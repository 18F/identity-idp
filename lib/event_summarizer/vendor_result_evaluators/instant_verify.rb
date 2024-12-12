# frozen_string_literal: true

module EventSummarizer
  module VendorResultEvaluators
    module InstantVerify
      # @param result {Hash} The result structure logged to Cloudwatch
      # @return [Hash] A Hash with a type and description keys.
      def self.evaluate_result(result)
        if result['success']
          return {
            type: :instant_verify_success,
            description: 'Instant Verify call succeeded',
          }
        end

        if result['timed_out']
          return {
            type: :instant_verify_timed_out,
            description: 'Instant Verify request timed out.',
          }
        end

        if result['exception']
          return {
            type: :instant_verify_exception,
            description: 'Instant Verify request resulted in an exception',
          }
        end

        # The API call failed because of actual errors in the user's data.
        # Try to come up with an explanation

        explanation = explain_errors(result) || 'Check logs for more info.'

        return {
          type: :instant_verify_error,
          description: "Instant Verify request failed. #{explanation}",
        }
      end

      # Attempts to render a legible explanation of what went wrong in a
      # LexisNexis Instant Verify request.
      # @param result {Hash} The result structure logged to Cloudwatch
      # @return {String}
      def self.explain_errors(result)
        # (The structure of the 'errors' key for Instant Verify is kind of weird)

        failed_items = []

        result.dig('errors', 'InstantVerify')&.each do |iv_instance|
          next if iv_instance['ProductStatus'] != 'fail'
          iv_instance['Items'].each do |item|
            if item['ItemStatus'] == 'fail'
              failed_items << item
            end
          end
        end

        if failed_items.empty?
          return 'Check the full logs for more info.'
        end

        checks = failed_items.map do |item|
          name = item['ItemName']
          reason = item['ItemReason']
          reason_code = reason ? reason['Code'] : nil

          if reason_code
            # TODO: Translate these reason codes to plain language
            # TODO: Add suggestions for how the user could remedy
            "#{name} (#{reason_code})"
          else
            name
          end
        end

        plural = checks.length == 1 ? '' : 's'

        "#{checks.length} check#{plural} failed: #{checks.join(", ")}"
      end
    end
  end
end
