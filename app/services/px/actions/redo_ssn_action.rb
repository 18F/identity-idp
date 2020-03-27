module Px
  module Actions
    class RedoSsnAction < Px::Steps::PxBaseStep
      def call
        mark_step_incomplete(:ssn)
      end
    end
  end
end
