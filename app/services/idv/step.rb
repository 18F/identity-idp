# abstract base class for Idv Steps
module Idv
  class Step
    include VendorValidated

    def initialize(analytics:, idv_form:, idv_session:, params:)
      @idv_form = idv_form
      @idv_session = idv_session
      @analytics = analytics
      @params = params
    end

    def form_valid?
      idv_form.submit(params)
    end

    def vendor_valid?
      vendor_validator.success?
    end

    def complete?
      raise NotImplementedError "Must implement complete? method for #{self}"
    end

    private

    attr_accessor :analytics, :idv_form, :idv_session, :params
    attr_reader :success

    def errors
      errors = idv_form.errors.messages.dup
      return errors unless vendor_errors
      merge_vendor_errors(errors)
    end

    def merge_vendor_errors(errors)
      vendor_errors.each_with_object(errors) do |(key, value), errs|
        value = [value] unless value.is_a?(Array)
        errs[key] = value
      end
    end

    def vendor_validator
      vendor_validator_class.new(idv_session: idv_session, vendor_params: vendor_params)
    end

    def analytics_event
      raise NotImplementedError "Must implement analytics_event for #{self}"
    end

    def result
      { success: success, errors: errors }
    end
  end
end
