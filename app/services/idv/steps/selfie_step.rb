module Idv
  module Steps
    class SelfieStep < DocAuthBaseStep
      def call
        is_live, is_face_match = ::Acuant::Liveness.new(instance_id).call(image.read)
        return selfie_failure unless is_live && is_face_match
      end

      private

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image, :image_data_url))
      end

      def instance_id
        flow_session[:instance_id]
      end

      def selfie_failure
        if mobile?
          mark_step_incomplete(:mobile_front_image)
          mark_step_incomplete(:mobile_back_image)
          mark_step_incomplete(:capture_mobile_back_image)
        else
          mark_step_incomplete(:front_image)
          mark_step_incomplete(:back_image)
        end
        failure(I18n.t('errors.doc_auth.selfie'))
      end
    end
  end
end
