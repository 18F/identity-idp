module Proofing
  module LexisNexis
    class VerificationErrorParser
      attr_reader :body

      # @param [Boolean] dob_year_only when true, only enforce that the year
      # from the date of birth must match
      def initialize(response_body, dob_year_only: false)
        @body = response_body
        @dob_year_only = dob_year_only
        @product_error_messages = parse_product_error_messages
        @base_error_message = parse_base_error_message
      end

      def dob_year_only?
        @dob_year_only
      end

      def parsed_errors
        { base: base_error_message }.merge(product_error_messages)
      end

      def verification_status
        @verification_status ||=
          begin
            status = body.dig('Status', 'TransactionStatus')

            if status == 'failed' && dob_year_only? && product_error_messages.empty?
              'passed'
            else
              status
            end
          end
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
          if product['ProductType'] == 'InstantVerify'
            original_passed = (product['ProductStatus'] == 'pass')
            passed_partial_dob = instant_verify_dob_year_only_pass?(product['Items'])

            Rails.logger.info(
              {
                name: 'lexisnexis_partial_dob',
                original_passed: original_passed,
                passed_partial_dob: passed_partial_dob,
                partial_dob_override_enabled: dob_year_only?,
              }.to_json,
            )

            next if original_passed || (dob_year_only? && passed_partial_dob)
          elsif product['ProductStatus'] == 'pass'
            next
          end

          key = product.fetch('ExecutedStepName').to_sym
          error_messages[key] = product
        end
      end

      # if DOBYearVerified passes, but DOBFullVerified fails, we can still allow a pass
      def instant_verify_dob_year_only_pass?(items)
        items ||= []
        dob_full_verified = items.find { |item| item['ItemName'] == 'DOBFullVerified' }
        dob_year_verified = items.find { |item| item['ItemName'] == 'DOBYearVerified' }
        other_checks = items.reject do |item|
          %w[DOBYearVerified DOBFullVerified].include?(item['ItemName'])
        end

        dob_full_verified.present? &&
          item_passed?(dob_year_verified) &&
          other_checks.all? { |item| item_passed?(item) }
      end

      def item_passed?(item)
        item && item['ItemStatus'] == 'pass'
      end
    end
  end
end
