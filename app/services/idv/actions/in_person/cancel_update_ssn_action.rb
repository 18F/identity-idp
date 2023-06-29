module Idv
  module Actions
    module InPerson
      class CancelUpdateSsnAction < Idv::Steps::DocAuthBaseStep
        include Idv::Steps::TempMaybeRedirectToVerifyInfoHelper

        def self.analytics_submitted_event
          :idv_doc_auth_cancel_update_ssn_submitted
        end

        def call
          mark_step_complete(:ssn) if flow_session.dig(:pii_from_user, :ssn)
          maybe_redirect_to_verify_info
        end
      end
    end
  end
end
