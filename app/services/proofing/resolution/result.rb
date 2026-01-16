# frozen_string_literal: true

module Proofing
  module Resolution
    class Result
      attr_reader :errors,
                  :exception,
                  :success,
                  :vendor_name,
                  :vendor_id, # e.g., SocureID
                  :transaction_id,
                  :customer_user_id,
                  :verified_attributes,
                  :failed_result_can_pass_with_additional_verification,
                  :attributes_requiring_additional_verification,
                  :reference,
                  :reason_codes,
                  :source_attribution,
                  :vendor_workflow
      def initialize(
        success: nil,
        errors: {},
        exception: nil,
        vendor_name: nil,
        vendor_id: nil,
        transaction_id: '',
        customer_user_id: '',
        reference: '',
        reason_codes: {},
        source_attribution: [],
        failed_result_can_pass_with_additional_verification: false,
        attributes_requiring_additional_verification: [],
        vendor_workflow: nil,
        verified_attributes: nil
      )
        @success = success
        @errors = errors
        @exception = exception
        @vendor_name = vendor_name
        @vendor_id = vendor_id
        @transaction_id = transaction_id
        @customer_user_id = customer_user_id
        @reference = reference
        @reason_codes = reason_codes
        @source_attribution = source_attribution
        @failed_result_can_pass_with_additional_verification =
          failed_result_can_pass_with_additional_verification
        @attributes_requiring_additional_verification =
          attributes_requiring_additional_verification
        @vendor_workflow = vendor_workflow
        @verified_attributes = verified_attributes
      end

      def success?
        success
      end

      def timed_out?
        exception.is_a?(Proofing::TimeoutError)
      end

      def to_h
        customer_user_id_hash = customer_user_id.present? ?
                                  { customer_user_id: customer_user_id } : {}
        {
          success: success?,
          errors: errors,
          exception: exception,
          timed_out: timed_out?,
          transaction_id: transaction_id,
          reference: reference,
          reason_codes: reason_codes,
          can_pass_with_additional_verification:
            failed_result_can_pass_with_additional_verification,
          attributes_requiring_additional_verification:
            attributes_requiring_additional_verification,
          source_attribution:,
          vendor_name:,
          vendor_id:,
          vendor_workflow:,
          verified_attributes:,
        }.merge(customer_user_id_hash)
      end

      def failed_result_can_pass_with_additional_verification?
        failed_result_can_pass_with_additional_verification
      end
    end
  end
end
