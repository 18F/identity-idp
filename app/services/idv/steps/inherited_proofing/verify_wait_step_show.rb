module Idv
  module Steps
    module InheritedProofing
      class VerifyWaitStepShow < VerifyBaseStep
        include UserPiiManagable
        delegate :controller, :idv_session, to: :@flow

        STEP_INDICATOR_STEP = :getting_started

        def call
          # binding.pry
          poll_with_meta_refresh(IdentityConfig.store.poll_rate_for_verify_in_seconds)

          process_async_state(async_state)
        end

        private

        def process_async_state(current_async_state)
          if current_async_state.none?
            mark_step_incomplete(:verify_wait)
          elsif current_async_state.in_progress?
            binding.pry
            nil
          elsif current_async_state.missing?
            flash[:error] = I18n.t('idv.failure.timeout')
            # Need to add path to error pages once they exist
            # LG-7257
            # This method overrides VerifyBaseStep#process_async_state:
            # See the VerifyBaseStep#process_async_state "elsif current_async_state.missing?"
            # logic as to what is typically needed/performed when hitting this logic path.
          elsif current_async_state.done?
            async_state_done(current_async_state)
          end
        end
      end
    end
  end
end
