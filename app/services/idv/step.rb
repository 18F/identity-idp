# abstract base class for Idv Steps
module Idv
  class Step
    def initialize(analytics:, idv_form:, idv_session:, params:)
      @idv_form = idv_form
      @idv_session = idv_session
      @analytics = analytics
      @params = params
    end

    def complete
      confirm if validate(params)
      track_event
      complete?
    end

    def complete?
      raise NotImplementedError "Must implement complete? method for #{self}"
    end

    private

    attr_accessor :analytics, :idv_form, :idv_session, :params, :form_result

    def validate(params)
      self.form_result = idv_form.submit(params)
    end

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

    def confirm
      raise NotImplementedError "Must implement confirm method for #{self}"
    end

    def confirmation_errors
      raise NotImplementedError "Must implement confirmation_errors method for #{self}"
    end

    def track_event
      raise NotImplementedError "Must implement track_event for #{self}"
    end

    def idv_vendor
      @_idv_vendor ||= Idv::Vendor.new
    end

    def idv_agent
      @_agent ||= Idv::Agent.new(
        applicant: idv_session.applicant,
        vendor: (idv_session.vendor || idv_vendor.pick)
      )
    end
  end
end
