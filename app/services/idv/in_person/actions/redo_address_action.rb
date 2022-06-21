module Idv
  module InPerson
    module Actions
      class RedoAddressAction < Idv::Steps::DocAuthBaseStep
        def call
          mark_step_incomplete(:address)
        end
      end
    end
  end
end
