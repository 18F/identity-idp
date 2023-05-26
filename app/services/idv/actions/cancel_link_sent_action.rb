module Idv
  module Actions
    class CancelLinkSentAction < Idv::Steps::DocAuthBaseStep
      def self.analytics_submitted_event
        :idv_doc_auth_cancel_link_sent_submitted
      end

      def call
        if IdentityConfig.store.doc_auth_hybrid_handoff_controller_enabled
          redirect_to idv_hybrid_handoff_url
        else
          mark_step_incomplete(:upload)
        end
      end
    end
  end
end
