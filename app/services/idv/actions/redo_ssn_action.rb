module Idv
  module Actions
    class RedoSsnAction < Idv::Steps::DocAuthBaseStep
      def self.analytics_submitted_event
        :idv_doc_auth_redo_ssn_submitted
      end

      def call
        mark_step_incomplete(:ssn)
      end
    end
  end
end
