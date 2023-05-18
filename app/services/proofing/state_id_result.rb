module Proofing
  class StateIdResult
    MVA_TIMEOUT_EXCEPTION = 'ExceptionId: 0047'.freeze

    attr_reader :errors,
                :exception,
                :success,
                :vendor_name,
                :transaction_id,
                :verified_attributes

    def initialize(
      success: nil,
      errors: {},
      exception: nil,
      vendor_name: nil,
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

    def mva_timeout?
      exception&.message&.include? MVA_TIMEOUT_EXCEPTION
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
