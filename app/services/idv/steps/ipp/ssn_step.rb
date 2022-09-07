module Idv
  module Steps
    module Ipp
      class SsnStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          flow_session[:pii_from_user][:ssn] = ssn

          @flow.irs_attempts_api_tracker.idv_ssn_submitted(
            success: true,
            ssn: ssn,
          )

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

        def generate_threatmetrix_session_id
          return unless service_provider_device_profiling_enabled?
          flow_session[:threatmetrix_session_id] = SecureRandom.uuid if !updating_ssn
          flow_session[:threatmetrix_session_id]
        end

        def ssn
          flow_params[:ssn]
        end

        def updating_ssn
          flow_session.dig(:pii_from_user, :ssn).present?
        end
      end
    end
  end
end
