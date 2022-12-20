module Proofing
  module LexisNexis
    class VerificationErrorParser
      attr_reader :body

      def initialize(response_body)
        @body = response_body
        @product_error_messages = parse_product_error_messages
        @base_error_message = parse_base_error_message
      end

      def parsed_errors
        { base: base_error_message }.merge(product_error_messages)
      end

      def verification_status
        @verification_status ||= body.dig('Status', 'TransactionStatus')
      end

      private

      attr_reader :base_error_message, :product_error_messages

      def parse_base_error_message
        return "Invalid status in response body: '#{verification_status}'" if !valid_status?

        if verification_status == 'error'
          error_information = body.fetch('Information', {}).to_json
          "Response error with code '#{error_code}': #{error_information}"
        elsif error_code.nil?
          'Verification failed without a reason code'
        else
          "Verification failed with code: '#{error_code}'"
        end
      end

      def error_code
        body.dig('Status', 'TransactionReasonCode', 'Code')
      end

      def valid_status?
        %w[passed failed error].include?(verification_status)
      end

      def parse_product_error_messages
        products = body['Products']
        return {} if products.nil?

        products.each_with_object({}) do |product, error_messages|
          next unless should_log?(product)

          # don't log PhoneFinder reflected PII
          product.delete('ParameterDetails') if product['ProductType'] == 'PhoneFinder'

          key = product.fetch('ExecutedStepName').to_sym
          error_messages[key] = product
        end
      end

      def should_log?(product)
        return true if product['ProductStatus'] != 'pass'
        return true if product['ProductType'] == 'InstantVerify'
        return true if product['Items']&.flat_map(&:keys)&.include?('ItemReason')
        return false
      end

    end
  end
end
