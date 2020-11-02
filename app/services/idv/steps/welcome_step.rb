module Idv
  module Steps
    class WelcomeStep < DocAuthBaseStep
      def call
        mark_document_capture_or_image_upload_steps_complete
        create_document_capture_session(document_capture_session_uuid_key)
      end

      def form_submit
        return no_camera_redirect if params[:no_camera]

        skip_to_capture if params[:skip_upload] && FeatureManagement.document_capture_step_enabled?

        Idv::ConsentForm.new.submit(consent_form_params)
      end

      def consent_form_params
        params.permit(:ial2_consent_given)
      end

      private

      def skip_to_capture
        # Skips to `document_capture` step. Assumes that base step will have already flagged old
        # flow steps if `FeatureManagement.document_capture_step_enabled?`.
        #
        # See: `mark_document_capture_or_image_upload_steps_complete`
        mark_step_complete(:upload)
        mark_step_complete(:send_link)
        mark_step_complete(:link_sent)
        mark_step_complete(:email_sent)
      end

      def no_camera_redirect
        redirect_to idv_doc_auth_errors_no_camera_url
        exception = StandardError.new(
          'Doc Auth error: Javascript could not detect camera on mobile device.',
        )

        NewRelic::Agent.notice_error(exception)
        failure(exception)
      end
    end
  end
end
