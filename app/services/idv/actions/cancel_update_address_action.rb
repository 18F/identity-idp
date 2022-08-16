module Idv
  module Actions
    class CancelUpdateAddressAction < Idv::Steps::DocAuthBaseStep
      def call
        mark_step_complete(:address) if flow_session.dig(:pii_from_doc, :address1)
      end
    end
  end
end
