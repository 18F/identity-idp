module Idv
  module Steps
    module Ipp
      class VerifyStep < VerifyBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          enqueue_job false
        end

        def extra_view_variables
          {
            pii: pii,
            step_url: method(:idv_in_person_step_url),
          }
        end
      end
    end
  end
end
