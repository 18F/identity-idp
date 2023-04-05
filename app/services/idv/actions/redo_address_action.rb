module Idv
  module Actions
    class RedoAddressAction < Idv::Steps::DocAuthBaseStep
      def self.analytics_submitted_event
        :idv_doc_auth_redo_address_submitted
      end

      def call
        mark_step_incomplete(:address)
        redirect_to idv_address_url
      end
    end
  end
end
