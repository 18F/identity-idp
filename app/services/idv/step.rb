# abstract base class for Idv Steps
module Idv
  class Step
    def initialize(idv_form:, idv_session:, params:)
      @idv_form = idv_form
      @idv_session = idv_session
      @params = params
    end

    def form_valid?
      form_validate(params).success?
    end

    private

    attr_accessor :idv_session
    attr_reader :idv_form, :params

    def form_validate(params)
      @form_result ||= idv_form.submit(params)
    end

    def vendor_validation_passed?
      vendor_validator_result.success?
    end

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
      errors = idv_form.errors.messages.dup
      return errors unless form_valid? && vendor_errors
      merge_vendor_errors(errors)
    end

    def merge_vendor_errors(errors)
      vendor_errors.each_with_object(errors) do |(key, value), errs|
        value = [value] unless value.is_a?(Array)
        errs[key] = value
      end
    end

    def idv_vendor
      @_idv_vendor ||= Idv::Vendor.new
    end

    def vendor_errors
      @_vendor_errors ||= vendor_validator_result.errors
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
