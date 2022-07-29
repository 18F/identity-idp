module Idv
  module Steps
    class WelcomeStep < DocAuthBaseStep
      STEP_INDICATOR_STEP = :getting_started

      def call
        return no_camera_redirect if params[:no_camera]
        create_document_capture_session(document_capture_session_uuid_key)
        cancel_previous_in_person_enrollments
      end

      private

      def no_camera_redirect
        redirect_to idv_doc_auth_errors_no_camera_url
        msg = 'Doc Auth error: Javascript could not detect camera on mobile device.'
        failure(msg)
      end

      def cancel_previous_in_person_enrollments
        UspsInPersonProofing::EnrollmentHelper.
          cancel_stale_establishing_enrollments_for_user(current_user)
      end
    end
  end
end
