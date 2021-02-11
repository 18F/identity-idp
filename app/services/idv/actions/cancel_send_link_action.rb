module Idv
  module Actions
    class CancelSendLinkAction < Idv::Steps::DocAuthBaseStep
      def call
        mark_step_incomplete(:upload)
      end
    end
  end
end
