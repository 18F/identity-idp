module Idv
  module Steps
    class VerifyWaitStepShow < VerifyBaseStep
      def call
        result = perform_resolution_and_check_ssn
        if result.success?
          mark_step_complete(:verify_wait)
        else
          mark_step_incomplete(:verify)
        end
      end
    end
  end
end
