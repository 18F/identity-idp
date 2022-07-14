module Idv
  module Steps
    module Ipp
      class VerifyWaitStepShow < VerifyBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          poll_with_meta_refresh(IdentityConfig.store.poll_rate_for_verify_in_seconds)

          process_async_state(async_state)
        end
      end
    end
  end
end
