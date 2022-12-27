module Idv
  module Steps
    module InheritedProofing
      class GetStartedStep < InheritedProofingBaseStep
        STEP_INDICATOR_STEP = :getting_started

        def self.analytics_visited_event
          :idv_inherited_proofing_get_started_visited
        end

        def self.analytics_submitted_event
          :idv_inherited_proofing_get_started_submitted
        end

        def call
        end
      end
    end
  end
end
