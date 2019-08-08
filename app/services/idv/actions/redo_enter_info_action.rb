module Idv
  module Actions
    class RedoEnterInfoAction < Idv::Steps::DocAuthBaseStep
      def call
        mark_step_incomplete(:enter_info)
      end
    end
  end
end
