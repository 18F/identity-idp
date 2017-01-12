module Idv
  class PhoneStep < Step
    def complete?
      idv_form.phone && idv_session.phone_confirmation.try(:success?) ? true : false
    end

    private

    def vendor_validator_class
      Idv::PhoneValidator
    end

    def vendor_params
      idv_form.phone
    end

    def vendor_validate
      result = vendor_validator.validate
      update_idv_session if complete?
      result
    end

    def vendor_errors
      idv_session.phone_confirmation.try(:errors)
    end

    def update_idv_session
      idv_session.params = idv_form.idv_params
      idv_session.applicant.phone = idv_form.phone
    end

    def analytics_event
      Analytics::IDV_PHONE_CONFIRMATION
    end
  end
end
