module Idv
  module Steps
    class VerifyWaitStepShow < VerifyBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call
        poll_with_meta_refresh(IdentityConfig.store.poll_rate_for_verify_in_seconds)

        process_async_state(async_state)
      end

      private

      def pii
        flow_session[:pii_from_doc]
      end

      def delete_pii
        flow_session.delete(:pii_from_doc)
      end
    end
  end
end
