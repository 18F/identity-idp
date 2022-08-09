module Idv
  module Steps
    module Ipp
      class SsnStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          flow_session[:pii_from_user][:ssn] = flow_params[:ssn]

          if IdentityConfig.store.proofing_device_profiling_collecting_enabled
            flow_session[:threatmetrix_session_id] = threatmetrix_session_id
          end
        end

        def extra_view_variables
          {
            updating_ssn: flow_session[:pii_from_user][:ssn].present?,
          }
        end

        private

        def form_submit
          Idv::SsnFormatForm.new(current_user).submit(permit(:ssn))
        end

        def threatmetrix_session_id
          return nil if !IdentityConfig.store.proofing_device_profiling_collecting_enabled
          SecureRandom.uuid
        end
      end
    end
  end
end
