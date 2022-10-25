module Idv
  module Steps
    class VerifyStep < VerifyBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def self.analytics_visited_event
        :idv_doc_auth_verify_visited
      end

      def self.analytics_submitted_event
        :idv_doc_auth_verify_submitted
      end

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
