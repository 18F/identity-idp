module Proofing
  class StateIdResult
    attr_reader :success, :errors, :exception, :vendor_name, :transaction_id, :verified_attributes

    def initialize(
      success:,
      errors:,
      exception:,
      vendor_name:,
      transaction_id: '',
      verified_attributes: []
    )
      @success = success
      @errors = errors
      @exception = exception
      @vendor_name = vendor_name
      @transaction_id = transaction_id
      @verified_attributes = verified_attributes
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
        errors: errors,
        exception: exception,
        timed_out: timed_out?,
        transaction_id: transaction_id,
        vendor_name: vendor_name,
        verified_attributes: verified_attributes,
      }
    end
  end
end
