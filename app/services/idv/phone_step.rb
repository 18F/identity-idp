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
      vendor_validation_passed?
    end

    def update_idv_session
      idv_session.phone_confirmation = true
      idv_session.address_verification_mechanism = :phone
      idv_session.params = idv_form_params
    end
  end
end
