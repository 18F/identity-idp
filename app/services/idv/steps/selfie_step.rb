module Idv
  module Steps
    class SelfieStep < DocAuthBaseStep
      def call
        is_live, is_face_match = ::Acuant::Liveness.new(instance_id).call(image.read)
        return failure(I18n.t('errors.doc_auth.selfie')) unless is_live && is_face_match
      end

      private

      def form_submit
        Idv::ImageUploadForm.new.submit(permit(:image, :image_data_url))
      end

      def instance_id
        flow_session[:instance_id]
      end
    end
  end
end
