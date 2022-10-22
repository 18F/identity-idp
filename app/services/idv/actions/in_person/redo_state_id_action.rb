module Idv
  module Actions
    module InPerson
      class RedoStateIdAction < Idv::Steps::DocAuthBaseStep
        def self.analytics_submitted_event
          :idv_in_person_proofing_redo_state_id_submitted
        end

        def call
          mark_step_incomplete(:state_id)
        end
      end
    end
  end
end
