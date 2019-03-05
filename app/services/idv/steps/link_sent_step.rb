module Idv
  module Steps
    class LinkSentStep < DocAuthBaseStep
      def call
        dac = DocCapture.find_by(user_id: current_user.id)
        flow_session[:instance_id] = dac.acuant_token

        failure_data, data = verify_back_image
        return failure_data if failure_data

        extract_pii_from_doc(data)

        mark_steps_complete
      end

      private

      def mark_steps_complete
        %i[send_link link_sent email_sent mobile_front_image mobile_back_image front_image
           back_image].each do |step|
          mark_step_complete(step)
        end
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
