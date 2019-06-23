module Idv
  module Actions
    class ResetInPersonAction < Idv::Steps::DocAuthBaseStep
      def call
        reset
      end
    end
  end
end
