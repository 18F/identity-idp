module Idv
  module Steps
    class SsnStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call
        return invalid_state_response if invalid_state?

        flow_session[:pii_from_doc][:ssn] = flow_params[:ssn]

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

      def invalid_state?
        flow_session[:pii_from_doc].nil?
      end

      def updating_ssn
        flow_session.dig(:pii_from_doc, :ssn).present?
      end

      def invalid_state_response
        mark_step_incomplete(:document_capture)
        FormResponse.new(success: false)
      end

      def generate_threatmetrix_session_id
        return unless IdentityConfig.store.proofing_device_profiling_collecting_enabled
        flow_session[:threatmetrix_session_id] = SecureRandom.uuid if !updating_ssn
        flow_session[:threatmetrix_session_id]
      end
    end
  end
end
