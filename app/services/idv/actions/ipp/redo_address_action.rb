module Idv
  module Actions
    module Ipp
      class RedoAddressAction < Idv::Steps::DocAuthBaseStep
        def call
          mark_step_incomplete(:address)
        end
      end
    end
  end
end
