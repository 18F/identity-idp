# frozen_string_literal: true

module Proofing
  class StateIdResult
    MVA_UNAVAILABLE = 'ExceptionId: 0001'
    MVA_SYSTEM_ERROR = 'ExceptionId: 0002'
    MVA_TIMEOUT_EXCEPTION = 'ExceptionId: 0047'
    UNEXPECTED_ERROR_CODE = 'Unexpected status code'

    attr_reader :errors,
                :exception,
                :vendor_name,
                :transaction_id,
                :requested_attributes,
                :verified_attributes

    def initialize(
      success: nil,
      errors: {},
      exception: nil,
      vendor_name: nil,
      transaction_id: '',
      requested_attributes: {},
      verified_attributes: [],
      jurisdiction_in_maintenance_window: false
    )
      @success = success
      @errors = errors
      @exception = exception
      @vendor_name = vendor_name
      @transaction_id = transaction_id
      @requested_attributes = requested_attributes
      @verified_attributes = verified_attributes
      @jurisdiction_in_maintenance_window = jurisdiction_in_maintenance_window
    end

    def success?
      !!@success
    end

    def timed_out?
      exception.is_a?(Proofing::TimeoutError)
    end

    def mva_unavailable?
      exception&.message&.include? MVA_UNAVAILABLE
    end

    def mva_system_error?
      exception&.message&.include? MVA_SYSTEM_ERROR
    end

    def mva_timeout?
      exception&.message&.include? MVA_TIMEOUT_EXCEPTION
    end

    def mva_exception?
      mva_unavailable? || mva_system_error? || mva_timeout?
    end

    def unexpected_error_code_exception?
      exception&.message&.include? UNEXPECTED_ERROR_CODE
    end

    def jurisdiction_in_maintenance_window?
      !!@jurisdiction_in_maintenance_window
    end

    def to_h
      {
        success: success?,
        errors: errors,
        exception: exception,
        mva_exception: mva_exception?,
        requested_attributes: requested_attributes,
        timed_out: timed_out?,
        transaction_id: transaction_id,
        vendor_name: vendor_name,
        verified_attributes: verified_attributes,
        jurisdiction_in_maintenance_window: jurisdiction_in_maintenance_window?,
      }
    end

    def to_doc_auth_response
      DocAuth::Response.new(
        success: success?,
        errors: doc_auth_errors,
        exception:,
        extra: to_h,
      )
    end

    private

    def doc_auth_errors
      return {} if errors.empty? && !unexpected_error_code_exception?

      { state_id_verification: 'Document could not be verified.' }
    end
  end
end
