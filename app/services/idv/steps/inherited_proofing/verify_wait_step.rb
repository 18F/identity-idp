module Idv
  module Steps
    module InheritedProofing
      class VerifyWaitStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :getting_started

        def self.analytics_visited_event
          :idv_doc_auth_verify_wait_step_visited
        end

        def call; end
      end
    end
  end
end
