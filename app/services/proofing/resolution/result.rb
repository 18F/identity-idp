module Proofing
  module Resolution
    class Result
      attr_reader :errors,
                  :exception,
                  :success,
                  :vendor_name,
                  :transaction_id,
                  :verified_attributes,
                  :failed_result_can_pass_with_additional_verification,
                  :attributes_requiring_additional_verification,
                  :reference,
                  :vendor_workflow
      def initialize(
        success: nil,
        errors: {},
        exception: nil,
        vendor_name: nil,
        transaction_id: '',
        reference: '',
        failed_result_can_pass_with_additional_verification: false,
        attributes_requiring_additional_verification: [],
        vendor_workflow: nil
      )
        @success = success
        @errors = errors
        @exception = exception
        @vendor_name = vendor_name
        @transaction_id = transaction_id
        @reference = reference
        @failed_result_can_pass_with_additional_verification =
          failed_result_can_pass_with_additional_verification
        @attributes_requiring_additional_verification =
          attributes_requiring_additional_verification
        @vendor_workflow = vendor_workflow
      end

      def success?
        success
      end

      def timed_out?
        exception.is_a?(Proofing::TimeoutError)
      end

      def to_h
        {
          success: success?,
          errors:,
          exception:,
          timed_out: timed_out?,
          transaction_id:,
          reference:,
          can_pass_with_additional_verification:
            failed_result_can_pass_with_additional_verification,
          attributes_requiring_additional_verification:,
          vendor_name:,
          vendor_workflow:,
        }
      end

      def failed_result_can_pass_with_additional_verification?
        failed_result_can_pass_with_additional_verification
      end
    end
end
end
