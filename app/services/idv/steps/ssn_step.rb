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

        @flow.irs_attempts_api_tracker.idv_ssn_submitted(
          ssn: ssn,
        )

        idv_session.delete('applicant')
        # rubocop:disable Style/IfUnlessModifier
        if IdentityConfig.store.doc_auth_verify_info_controller_enabled
          exit_flow_state_machine
        end
        # rubocop:enable Style/IfUnlessModifier
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

      def exit_flow_state_machine
        mark_step_complete(:verify)
        mark_step_complete(:verify_wait)
        flow_session[:flow_path] = @flow.flow_path
        redirect_to idv_verify_info_url
      end
    end
  end
end
