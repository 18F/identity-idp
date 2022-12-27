module Idv
  module Actions
    module InPerson
      class CancelUpdateAddressAction < Idv::Steps::DocAuthBaseStep
        def self.analytics_submitted_event
          :idv_in_person_proofing_cancel_update_address
        end

        def call
          mark_step_complete(:address) if flow_session.dig(:pii_from_user, :address1)
        end
      end
    end
  end
end
