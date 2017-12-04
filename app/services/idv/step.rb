# abstract base class for Idv Steps
module Idv
  class Step
    def initialize(idv_session:, idv_form_params:, vendor_validator_result:)
      @idv_form_params = idv_form_params
      @idv_session = idv_session
      @vendor_validator_result = vendor_validator_result
    end

    def vendor_validation_passed?
      return false if vendor_validator_job_failed?
      vendor_validator_result.success?
    end

    def vendor_validation_timed_out?
      vendor_validator_result.timed_out?
    end

    def vendor_validator_job_failed?
      vendor_validator_result&.job_failed?
    end

    private

    attr_accessor :idv_session
    attr_reader :idv_form_params, :vendor_validator_result

    def errors
      @_errors ||= begin
        vendor_validator_result.errors.each_with_object({}) do |(key, value), errs|
          errs[key] = Array(value)
        end
      end
    end
  end
end
