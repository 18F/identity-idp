module Idv
  module Steps
    class VerifyStep < VerifyBaseStep
      def call
        perform_resolution_and_check_ssn
      end
    end
  end
end
