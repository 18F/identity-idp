module Idv
  module Steps
    module Ipp
      class SsnStep < DocAuthBaseStep
        STEP_INDICATOR_STEP = :verify_info

        def call
          unless updating_ssn
            flow_session[:threatmetrix_session_id] = generate_threatmetrix_session_id
          end
          flow_session[:pii_from_user][:ssn] = flow_params[:ssn]

          idv_session.delete('applicant')
        end

        def extra_view_variables
          {
            updating_ssn: updating_ssn,
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
          SecureRandom.uuid
        end
      end
    end
  end
end
