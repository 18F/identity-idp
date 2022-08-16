module Idv
  module Steps
    module Ipp
      class SsnStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          flow_session[:pii_from_user][:ssn] = flow_params[:ssn]

          idv_session.delete('applicant')
        end

        def extra_view_variables
          {
            updating_ssn: updating_ssn,
            threatmetrix_session_id: generate_threatmetrix_session_id,
          }
        end

        private

        def form_submit
          Idv::SsnFormatForm.new(current_user).submit(permit(:ssn))
        end

        def updating_ssn
          flow_session.dig(:pii_from_user, :ssn).present?
        end

        def generate_threatmetrix_session_id
          return unless IdentityConfig.store.proofing_device_profiling_collecting_enabled
          if flow_session[:threatmetrix_session_id].nil? && !updating_ssn
            flow_session[:threatmetrix_session_id] = SecureRandom.uuid
          end
        end
      end
    end
  end
end
