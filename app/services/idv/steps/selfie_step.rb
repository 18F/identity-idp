module Idv
  module Steps
    class SelfieStep < DocAuthBaseStep
      def call
        success, error_results = ::Acuant::Liveness.new(instance_id).call(image.read)
        if success
          return unless user_id_from_token
          CaptureDoc::UpdateAcuantToken.call(user_id_from_token, flow_session[:instance_id])
        else
          selfie_failure(error_results)
        end
      end

      private

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image, :image_data_url))
      end

      def instance_id
        flow_session[:instance_id]
      end

      def selfie_failure(error_results)
        if mobile?
          mark_step_incomplete(:mobile_front_image)
          mark_step_incomplete(:mobile_back_image)
          mark_step_incomplete(:capture_mobile_back_image)
        else
          mark_step_incomplete(:front_image)
          mark_step_incomplete(:back_image)
        end
        failure(I18n.t('errors.doc_auth.selfie'), error_results)
      end
    end
  end
end
