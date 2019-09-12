module Idv
  module Steps
    class LinkSentStep < DocAuthBaseStep
      def call
        dac = DocCapture.find_by(user_id: current_user.id)
        flow_session[:instance_id] = dac.acuant_token

        failure_data, data = verify_back_image(reset_step: :send_link)
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
    end
  end
end
