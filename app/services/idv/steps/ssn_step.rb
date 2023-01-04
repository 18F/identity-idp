module Idv
  module Steps
    class SsnStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :verify_info

      include ThreatMetrixStepHelper

      def self.analytics_visited_event
        :idv_doc_auth_ssn_visited
      end

      def self.analytics_submitted_event
        :idv_doc_auth_ssn_submitted
      end

      def call
        return invalid_state_response if invalid_state?

        flow_session[:pii_from_doc][:ssn] = ssn
        add_verify_info_variables

        @flow.irs_attempts_api_tracker.idv_ssn_submitted(
          ssn: ssn,
        )

        idv_session.delete('applicant')
      end

      def add_verify_info_variables
        flow_session[:flow_path] = @flow.flow_path
      end

      def extra_view_variables
        {
          updating_ssn: updating_ssn,
          **threatmetrix_view_variables,
        }
      end

      private

      def form_submit
        Idv::SsnFormatForm.new(current_user).submit(permit(:ssn))
      end

      def invalid_state_response
        mark_step_incomplete(:document_capture)
        FormResponse.new(success: false)
      end

      def ssn
        flow_params[:ssn]
      end

      def invalid_state?
        flow_session[:pii_from_doc].nil?
      end

      def updating_ssn
        flow_session.dig(:pii_from_doc, :ssn).present?
      end
    end
  end
end
