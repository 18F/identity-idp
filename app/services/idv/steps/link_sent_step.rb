module Idv
  module Steps
    class LinkSentStep < DocAuthBaseStep
      def call
        error = check_if_take_photo_with_phone_successful
        return error if error

        failure_data, data = verify_back_image(reset_step: :send_link)
        return failure_data if failure_data

        extract_pii_from_doc(data)

        mark_steps_complete
      end

      private

      def check_if_take_photo_with_phone_successful
        dac = DocCapture.find_by(user_id: user_id)
        token = dac.acuant_token
        if token
          flow_session[:instance_id] = token
          false
        else
          failure(I18n.t('errors.doc_auth.phone_step_incomplete'))
        end
      end

      def mark_steps_complete
        %i[send_link link_sent email_sent mobile_front_image mobile_back_image front_image
           back_image scan_id].each do |step|
          mark_step_complete(step)
        end
        mark_step_complete(:selfie) unless liveness_checking_enabled?
      end
    end
  end
end
