module Idv
  module Steps
    class VerifyWaitStep < VerifyBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call; end

      def track_optional_step(analytics, payload)
        analytics.idv_doc_auth_verify_optional_wait_step(**payload)
      end
    end
  end
end
