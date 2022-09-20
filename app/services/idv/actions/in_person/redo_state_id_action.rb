module Idv
  module Actions
    module InPerson
      class RedoStateIdAction < Idv::Steps::DocAuthBaseStep
        def call
          mark_step_incomplete(:state_id)
        end
      end
    end
  end
end
