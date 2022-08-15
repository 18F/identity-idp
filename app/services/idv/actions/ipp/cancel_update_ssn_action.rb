module Idv
  module Actions
    module Ipp
      class CancelUpdateSsnAction < Idv::Steps::DocAuthBaseStep
        def call
          mark_step_complete(:ssn) if flow_session.dig(:pii_from_user, :ssn)
        end
      end
    end
  end
end
