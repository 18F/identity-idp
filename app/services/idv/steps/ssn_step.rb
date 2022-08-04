module Idv
  module Steps
    class SsnStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :verify_info

      def call
        return invalid_state_response if invalid_state?

        flow_session[:pii_from_doc][:ssn] = flow_params[:ssn]

        if IdentityConfig.store.proofing_device_profiling_collecting_enabled
          flow_session[:threatmetrix_session_id] = threatmetrix_session_id
        end
      end

      def extra_view_variables
        {
          updating_ssn: flow_session.dig(:pii_from_doc, :ssn).present?,
        }
      end

      private

      def form_submit
        Idv::SsnFormatForm.new(current_user).submit(permit(:ssn))
      end

      def invalid_state?
        flow_session[:pii_from_doc].nil?
      end

      def invalid_state_response
        mark_step_incomplete(:document_capture)
        FormResponse.new(success: false)
      end

      def threatmetrix_session_id
        return nil if !IdentityConfig.store.proofing_device_profiling_collecting_enabled
        SecureRandom.uuid
      end
    end
  end
end
