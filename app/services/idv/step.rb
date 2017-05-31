# abstract base class for Idv Steps
module Idv
  class Step
    def initialize(idv_form:, idv_session:, params:)
      @idv_form = idv_form
      @idv_session = idv_session
      @params = params
    end

    def form_valid?
      form_validate(params)
    end

    private

    attr_accessor :idv_session
    attr_reader :idv_form, :params

    def form_validate(params)
      @form_result ||= idv_form.submit(params)
    end

    def vendor_validation_passed?
      vendor_validator.success?
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

    def vendor_errors
      @_vendor_errors ||= vendor_validator.errors
    end

    def vendor_validator
      @_vendor_validator ||= vendor_validator_class.new(
        idv_session: idv_session,
        vendor_params: vendor_params
      )
    end
  end
end
