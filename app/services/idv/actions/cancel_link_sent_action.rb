module Idv
  module Actions
    class CancelLinkSentAction < Idv::Steps::DocAuthBaseStep
      def call
        mark_step_incomplete(:send_link)
      end
    end
  end
end
