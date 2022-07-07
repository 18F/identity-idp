module Idv
  module Steps
    module Ipp
      class VerifyStep < VerifyBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          pii[:state_id_type] = 'drivers_license'
          enqueue_job
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
