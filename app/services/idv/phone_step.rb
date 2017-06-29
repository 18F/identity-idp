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

    def form_valid_but_vendor_validation_failed?
      form_valid? && !vendor_validation_passed?
    end

    private

    def complete?
      form_valid? && vendor_validation_passed?
    end

    def vendor_validator_class
      Idv::PhoneValidator
    end

    def vendor_params
      idv_form.phone
    end

    def vendor_reasons
      vendor_validator_result.reasons if form_valid?
    end

    def update_idv_session
      idv_session.phone_confirmation = true
      idv_session.address_verification_mechanism = :phone
      idv_session.params = idv_form.idv_params
    end
  end
end
