module Idv
  module Steps
    class VerifyStep < VerifyBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call
        enqueue_job
      end

      def extra_view_variables
        {
          pii: pii,
          step_url: method(:idv_doc_auth_step_url),
        }
      end

      private

      def pii
        flow_session[:pii_from_doc]
      end
    end
  end
end
