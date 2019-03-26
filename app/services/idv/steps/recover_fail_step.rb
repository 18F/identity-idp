module Idv
  module Steps
    class RecoverFailStep < DocAuthBaseStep
      def call
        reset
        mark_step_complete(:recover)
      end
    end
  end
end
