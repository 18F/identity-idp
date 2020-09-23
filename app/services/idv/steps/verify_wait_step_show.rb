module Idv
  module Steps
    class VerifyWaitStepShow < VerifyBaseStep
      def call
        poll_with_meta_refresh(Figaro.env.poll_rate_for_verify_in_seconds.to_i)
        result = perform_resolution_and_check_ssn
        if result.success?
          mark_step_complete(:verify_wait)
        else
          # return if result says continue to wait else...
          mark_step_incomplete(:verify)
        end
      end
    end
  end
end
