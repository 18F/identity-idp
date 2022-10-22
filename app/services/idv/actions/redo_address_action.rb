module Idv
  module Actions
    class RedoAddressAction < Idv::Steps::DocAuthBaseStep
      def analytics_submitted_event
        :idv_doc_auth_redo_address_submitted
      end

      def call
        redirect_to idv_address_url
      end
    end
  end
end
