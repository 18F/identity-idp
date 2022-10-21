module Idv
  module Steps
    class VerifyWaitStep < VerifyBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def self.analytics_visited_event
        :idv_doc_auth_verify_wait_step_visited
      end

      def call; end
    end
  end
end
