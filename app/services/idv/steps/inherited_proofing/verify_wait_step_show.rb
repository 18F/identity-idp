module Idv
  module Steps
    module InheritedProofing
      class VerifyWaitStepShow < VerifyBaseStep
        include UserPiiManagable
        delegate :controller, :idv_session, to: :@flow

        STEP_INDICATOR_STEP = :getting_started

        def call
          poll_with_meta_refresh(IdentityConfig.store.poll_rate_for_verify_in_seconds)

          process_async_state(async_state)
        end

        private

        def process_async_state(current_async_state)
          if current_async_state.none?
            inherited_proofing_save_user_pii_to_session!
            inherited_proofing_form_response
          elsif current_async_state.in_progress?
            nil
          elsif current_async_state.missing?
            flash[:error] = I18n.t('idv.failure.timeout')
            # Need to add path to error pages once they exist
          elsif current_async_state.done?
            async_state_done(current_async_state)
          end
        end
      end
    end
  end
end
