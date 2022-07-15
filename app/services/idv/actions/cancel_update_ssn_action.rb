module Idv
  module Actions
    class CancelUpdateSsnAction < Idv::Steps::DocAuthBaseStep
      def call
        mark_step_complete(:ssn) if flow_session.dig(:pii_from_doc, :ssn)
      end
    end
  end
end
