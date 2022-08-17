module Idv
  module Actions
    module Ipp
      class CancelUpdateStateIdAction < Idv::Steps::DocAuthBaseStep
        def call
          mark_step_complete(:state_id) if flow_session.dig(:pii_from_user, :first_name)
        end
      end
    end
  end
end
