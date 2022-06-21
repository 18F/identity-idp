module Idv
  module Actions
    class RedoAddressAction < Idv::Steps::DocAuthBaseStep
      def call
        redirect_to idv_address_url
      end
    end
  end
end
