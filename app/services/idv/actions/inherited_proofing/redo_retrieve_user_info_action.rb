module Idv
  module Actions
    module InheritedProofing
      class RedoRetrieveUserInfoAction < Idv::Steps::InheritedProofing::VerifyWaitStepShow
        class << self
          def analytics_submitted_event
            :idv_inherited_proofing_redo_retrieve_user_info_submitted
          end
        end

        def call
          enqueue_job unless api_call_already_in_progress?

          super
        end
      end
    end
  end
end
