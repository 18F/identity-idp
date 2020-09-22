module Idv
  module Steps
    class VerifyWaitStepShow < VerifyBaseStep
      def call
        result = perform_resolution_and_check_ssn
        mark_step_complete(:verify_wait) if result.success?
      end
    end
  end
end
