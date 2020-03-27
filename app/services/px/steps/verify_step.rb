module Px
  module Steps
    class VerifyStep < Idv::Steps::VerifyBaseStep
      def call
        perform_resolution_and_check_ssn
      end
    end
  end
end
