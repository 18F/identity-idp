module Idv
  module Actions
    class CancelLinkSentAction < Idv::Steps::DocAuthBaseStep
      def self.analytics_submitted_event
        :idv_doc_auth_cancel_link_sent_submitted
      end

      def call
        mark_step_incomplete(:send_link)
        if IdentityConfig.store.doc_auth_combined_hybrid_handoff_enabled
          mark_step_incomplete(:upload)
        end
      end
    end
  end
end
