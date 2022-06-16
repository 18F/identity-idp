module Idv
  module Actions
    class RedoDocauthAction < Idv::Steps::DocAuthBaseStep
      def call
        mark_step_incomplete(:ssn)
        mark_step_incomplete(:document_capture)
      end
    end
  end
end
