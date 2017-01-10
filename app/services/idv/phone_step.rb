module Idv
  class PhoneStep < Step
    def complete?
      idv_form.phone && idv_session.phone_confirmation.try(:success?) ? true : false
    end

    private

    def confirm
      phone_number = idv_form.phone
      session_id = idv_session.resolution.session_id
      idv_session.phone_confirmation = idv_agent.submit_phone(phone_number, session_id)
      update_idv_session if complete?
      idv_session.phone_confirmation.success?
    end

    def update_idv_session
      idv_session.params = idv_form.idv_params
      idv_session.applicant.phone = idv_form.phone
    end

    def track_event
      result = {
        success: complete?
      }

      analytics.track_event(Analytics::IDV_PHONE_CONFIRMATION, result)
    end
  end
end
