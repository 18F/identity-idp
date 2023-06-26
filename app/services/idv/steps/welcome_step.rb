module Idv
  module Steps
    class WelcomeStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :getting_started

      def self.analytics_visited_event
        :idv_doc_auth_welcome_visited
      end

      def self.analytics_submitted_event
        :idv_doc_auth_welcome_submitted
      end

      def call
        flow_session[:skip_upload_step] = true unless FeatureManagement.idv_allow_hybrid_flow?

        create_document_capture_session(document_capture_session_uuid_key)
        cancel_previous_in_person_enrollments

        redirect_to idv_agreement_url
      end

      private

      def cancel_previous_in_person_enrollments
        return unless IdentityConfig.store.in_person_proofing_enabled
        UspsInPersonProofing::EnrollmentHelper.
          cancel_stale_establishing_enrollments_for_user(current_user)
      end
    end
  end
end
