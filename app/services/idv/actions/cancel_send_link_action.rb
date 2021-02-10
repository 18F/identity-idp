module Idv
  module Actions
    class CancelSendLinkAction < Idv::Steps::DocAuthBaseStep
      def call
        mark_step_incomplete(:upload)
        mark_step_incomplete(:send_link)
        mark_step_incomplete(:link_sent)
      end
    end
  end
end
