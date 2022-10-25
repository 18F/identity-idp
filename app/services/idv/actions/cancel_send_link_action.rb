module Idv
  module Actions
    class CancelSendLinkAction < Idv::Steps::DocAuthBaseStep
      def self.analytics_submitted_event
        :idv_doc_auth_cancel_send_link_submitted
      end

      def call
        mark_step_incomplete(:upload)
      end
    end
  end
end
