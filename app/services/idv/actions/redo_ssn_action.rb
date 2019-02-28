module Idv
  module Actions
    class RedoSsnAction < Idv::Steps::DocAuthBaseStep
      def call
        mark_step_incomplete(:ssn)
      end
    end
  end
end
