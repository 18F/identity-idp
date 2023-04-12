module Idv
  module Steps
    class CaptureCompleteStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :verify_id

      def self.analytics_visited_event
        :idv_doc_auth_capture_complete_visited
      end

      def call; end
    end
  end
end
