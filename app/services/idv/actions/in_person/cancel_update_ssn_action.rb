module Idv
  module Actions
    module InPerson
      class CancelUpdateSsnAction < Idv::Steps::DocAuthBaseStep
        def call
          mark_step_complete(:ssn) if flow_session.dig(:pii_from_user, :ssn)
        end
      end
    end
  end
end
