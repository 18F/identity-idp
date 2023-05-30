module Idv
  module Actions
    class CancelLinkSentAction < Idv::Steps::DocAuthBaseStep
      def self.analytics_submitted_event
        :idv_doc_auth_cancel_link_sent_submitted
      end

      def call
        redirect_to idv_hybrid_handoff_url
      end
    end
  end
end
