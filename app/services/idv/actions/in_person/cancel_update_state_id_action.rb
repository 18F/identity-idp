module Idv
  module Actions
    module InPerson
      class CancelUpdateStateIdAction < Idv::Steps::DocAuthBaseStep
        include Idv::Steps::TempMaybeRedirectToVerifyInfoHelper

        def self.analytics_submitted_event
          :idv_in_person_proofing_cancel_update_state_id
        end

        def call
          mark_step_complete(:state_id) if flow_session.dig(:pii_from_user, :first_name)
          maybe_redirect_to_verify_info
        end
      end
    end
  end
end
