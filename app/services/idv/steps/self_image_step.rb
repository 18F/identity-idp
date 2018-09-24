module Idv
  module Steps
    class SelfImageStep < DocAuthBaseStep
      def call
        success, data = verify_image(image)
        return failure(data) unless success

        return failure(I18n.t('doc_auth.errors.selfie')) unless data['FacialMatch']

        step_successful(data)
      end

      private

      def form_submit
        Idv::ImageUploadForm.new(current_user).submit(permit(:image))
      end

      def step_successful(data)
        save_doc_auth
        flow_session[:image_verification_data] = data
      end

      def save_doc_auth
        doc_auth.license_confirmed_at = Time.zone.now
        doc_auth.save
      end

      def verify_image(self_image)
        face_image_verified, data = assure_id.face_image
        return failure(data) unless face_image_verified

        decoded_self_image = Base64.decode64(self_image.sub('data:image/png;base64,', ''))
        Idv::Utils::ImagesToTmpFiles.new(data, decoded_self_image).call do |tmp_images|
          facial_match.call(*tmp_images)
        end
      end

      def facial_match
        @facial_match ||= Idv::Acuant::FacialMatch.new
      end

      def doc_auth
        @doc_auth ||= ::DocAuth.find_or_create_by(user_id: current_user.id)
      end
    end
  end
end
