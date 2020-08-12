module Idv
  module Steps
    class WelcomeStep < DocAuthBaseStep
      def call
        mark_document_capture_or_image_upload_steps_complete
      end

      def form_submit
        skip_to_capture if params[:skip_upload] && FeatureManagement.document_capture_step_enabled?

        Idv::ConsentForm.new.submit(consent_form_params)
      end

      def consent_form_params
        params.permit(:ial2_consent_given)
      end

      private

      def skip_to_capture
        mark_step_complete(:upload)
        mark_step_complete(:send_link)
        mark_step_complete(:link_sent)
        mark_step_complete(:email_sent)
        mark_step_complete(:mobile_front_image)
        mark_step_complete(:mobile_back_image)
        mark_step_complete(:mobile_document_capture)
      end
    end
  end
end
