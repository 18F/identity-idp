module Idv
  class PhoneStep < Step
    def submit
      if complete?
        update_idv_session
      else
        idv_session.phone_confirmation = false
      end

      FormResponse.new(success: complete?, errors: errors)
    end

    private

    def complete?
      form_valid? && vendor_validator.success?
    end

    def vendor_validator_class
      Idv::PhoneValidator
    end

    def vendor_params
      idv_form.phone
    end

    def vendor_errors
      vendor_validator.errors if form_valid?
    end

    def update_idv_session
      idv_session.phone_confirmation = true
      idv_session.params = idv_form.idv_params
      idv_session.applicant.phone = idv_form.phone
    end
  end
end
