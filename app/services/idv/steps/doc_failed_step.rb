module Idv
  module Steps
    class DocFailedStep < DocAuthBaseStep
      def call
        reset
      end
    end
  end
end
