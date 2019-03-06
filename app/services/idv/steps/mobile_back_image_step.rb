module Idv
  module Steps
    class MobileBackImageStep < DocAuthBaseStep
      def call
        good, data = assure_id.post_back_image(image.read)
        return failure(data) unless good

        failure_data, data = verify_back_image
        return failure_data if failure_data

        extract_pii_from_doc(data)
      end

      private

      def form_submit
        Idv::ImageUploadForm.new(current_user).submit(permit(:image))
      end

      def extract_pii_from_doc(data)
        pii_from_doc = Idv::Utils::PiiFromDoc.new(data).call(
          current_user.phone_configurations.first.phone,
        )
        flow_session[:pii_from_doc] = pii_from_doc
      end

      def verify_back_image
        back_image_verified, data = assure_id.results
        return failure(data) unless back_image_verified

        return [nil, data] if data['Result'] == BAD_RESULT

        failure_alerts(data)
      end

      def failure_alerts(data)
        failure(data['Alerts'].
          reject { |res| res['Result'] == FYI_RESULT }.
          map { |act| act['Actions'] })
      end
    end
  end
end
