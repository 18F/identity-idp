module Proofing
  module LexisNexis
    class VerificationErrorParser
      attr_reader :body

      # @param [Boolean] dob_year_only when true, only enforce that the year
      # from the date of birth must match
      def initialize(response_body, dob_year_only: false)
        @body = response_body
        @dob_year_only = dob_year_only
        @base_error_message = parse_base_error_message
        @product_error_messages = parse_product_error_messages
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
        error_code = body.dig('Status', 'TransactionReasonCode', 'Code')
        conversation_id = body.dig('Status', 'ConversationId')
        reference = body.dig('Status', 'Reference')
        tracking_ids = "(LN ConversationId: #{conversation_id}; Reference: #{reference}) "

        return "#{tracking_ids} Verification failed without a reason code" if error_code.nil?

        "#{tracking_ids} Verification failed with code: '#{error_code}'"
      end

      def parse_product_error_messages
        products = body['Products']
        return { products: 'Products missing from response' } if products.nil?

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
          else
            next if product['ProductStatus'] == 'pass'
          end

          key = product.fetch('ExecutedStepName').to_sym
          error_messages[key] = product
        end
      end

      # if DOBYearVerified passes, but DOBFullVerified fails, we can still allow a pass
      def instant_verify_dob_year_only_pass?(items)
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
