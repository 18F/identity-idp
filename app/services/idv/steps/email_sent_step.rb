module Idv
  module Steps
    class EmailSentStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :verify_id

      def self.analytics_visited_event
        :idv_doc_auth_email_sent_visited
      end

      def call; end
    end
  end
end
