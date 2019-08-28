module Idv
  module Steps
    class SendLinkStep < DocAuthBaseStep
      def call
        capture_doc = CaptureDoc::CreateRequest.call(current_user.id)
        begin
          Telephony.send_doc_auth_link(
            to: permit(:phone)[:phone],
            link: link(capture_doc.request_token),
          )
        rescue Telephony::TelephonyError => err
          return failure(err.friendly_message)
        end
      end

      private

      def form_submit
        Idv::PhoneForm.new(previous_params: {}, user: current_user).submit(permit(:phone))
      end

      def link(token)
        idv_capture_doc_step_url(step: :mobile_front_image, token: token)
      end
    end
  end
end
