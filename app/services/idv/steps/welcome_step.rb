module Idv
  module Steps
    class WelcomeStep < DocAuthBaseStep
      def call
        mark_document_capture_or_image_upload_steps_complete
      end

      def form_submit
        Idv::ConsentForm.new.submit(consent_form_params)
      end

      def consent_form_params
        params.permit(:ial2_consent_given)
      end
    end
  end
end
