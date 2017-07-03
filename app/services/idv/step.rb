# abstract base class for Idv Steps
module Idv
  class Step
    def initialize(idv_session:, idv_form_params:, vendor_params:)
      @idv_form_params = idv_form_params
      @idv_session = idv_session
      @vendor_params = vendor_params
    end

    def vendor_validation_passed?
      vendor_validator_result.success?
    end

    private

    attr_accessor :idv_session
    attr_reader :idv_form_params, :vendor_params

    def vendor_validator_result
      @_vendor_validator_result ||= extract_vendor_result(vendor_validator.result)
    end

    def extract_vendor_result(result)
      vendor_resp = result.vendor_resp

      Idv::VendorResult.new(
        success: result.success?,
        errors: result.errors,
        reasons: vendor_resp.reasons,
        normalized_applicant: vendor_resp.try(:normalized_applicant),
        session_id: result.try(:session_id)
      )
    end

    def errors
      @_errors ||= begin
        vendor_validator_result.errors.each_with_object({}) do |(key, value), errs|
          errs[key] = Array(value)
        end
      end
    end

    def idv_vendor
      @_idv_vendor ||= Idv::Vendor.new
    end

    def vendor_validator
      @_vendor_validator ||= vendor_validator_class.new(
        applicant: idv_session.applicant,
        vendor: (idv_session.vendor || idv_vendor.pick),
        vendor_params: vendor_params,
        vendor_session_id: idv_session.vendor_session_id
      )
    end
  end
end
