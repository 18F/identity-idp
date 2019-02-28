module Idv
  module Steps
    class CaptureMobileBackImageStep < DocAuthBaseStep
      def call
        good, data = assure_id.post_back_image(image.read)
        return failure(data) unless good

        failure_data, _data = verify_back_image
        return failure_data if failure_data

        CaptureDoc::UpdateAcuantToken.call(user_id_from_token, flow_session[:instance_id])
      end

      private

      def form_submit
        Idv::ImageUploadForm.new(current_user).submit(permit(:image))
      end

      def verify_back_image
        back_image_verified, data = assure_id.results
        return failure(data) unless back_image_verified

        return [nil, data] if data['Result'] == 1

        failure_alerts(data)
      end

      def failure_alerts(data)
        failure(data['Alerts'].
          reject { |res| res['Result'] == 2 }.
          map { |act| act['Actions'] })
      end

      def user_id_from_token
        flow_session[:capture_user_id]
      end
    end
  end
end
