# frozen_string_literal: true

module Proofing
  class AddressResult
    attr_reader :success,
                :errors,
                :exception,
                :vendor_name,
                :transaction_id,
                :reference,
                :vendor_workflow,
                :reason_codes,
                :customer_user_id

    def initialize(
      success:,
      errors:,
      exception:,
      vendor_name:,
      transaction_id: '',
      reference: '',
      vendor_workflow: nil,
      reason_codes: nil,
      customer_user_id: nil
    )
      @success = success
      @errors = errors
      @exception = exception
      @vendor_name = vendor_name
      @transaction_id = transaction_id
      @reference = reference
      @vendor_workflow = vendor_workflow
      @reason_codes = reason_codes
      @customer_user_id = customer_user_id
    end

    def success?
      success
    end

    def timed_out?
      exception.is_a?(Proofing::TimeoutError)
    end

    def to_h
      {
        exception: exception,
        errors: errors,
        success: success?,
        timed_out: timed_out?,
        transaction_id: transaction_id,
        reference: reference,
        vendor_name: vendor_name,
        reason_codes:,
        customer_user_id:,
      }
    end
  end
end
