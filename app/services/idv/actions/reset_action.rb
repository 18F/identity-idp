module Idv
  module Actions
    class ResetAction < Idv::Steps::DocAuthBaseStep
      def call
        reset
      end
    end
  end
end
