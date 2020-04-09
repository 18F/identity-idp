module Idv
  module Steps
    class SendLinkStep < DocAuthBaseStep
      def call
        return failure(I18n.t('errors.doc_auth.send_link_throttle')) if throttled_else_increment
        telephony_result = send_link
        return failure(telephony_result.error.friendly_message) unless telephony_result.success?
      end

      private

      def send_link
        capture_doc = CaptureDoc::CreateRequest.call(user_id)
        Telephony.send_doc_auth_link(
          to: formatted_destination_phone,
          link: link(capture_doc.request_token),
        )
      end

      def form_submit
        Idv::PhoneForm.new(previous_params: {}, user: current_user).submit(permit(:phone))
      end

      def formatted_destination_phone
        raw_phone = permit(:phone)[:phone]
        PhoneFormatter.format(raw_phone, country_code: 'US')
      end

      def link(token)
        if request.path.include?('doc_auth_v2')
          idv_doc_auth_v2_step_dashes_url(step: :scan_idto_s.dasherize, token: token)
        else
          idv_capture_doc_step_dashes_url(step: :mobile_front_image.to_s.dasherize, token: token)
        end
      end

      def throttled_else_increment
        Throttler::IsThrottledElseIncrement.call(user_id, :idv_send_link)
      end
    end
  end
end
