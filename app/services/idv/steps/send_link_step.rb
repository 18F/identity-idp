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
        session_uuid = flow_session[:document_capture_session_uuid]
        update_document_capture_session_requested_at(session_uuid)
        Telephony.send_doc_auth_link(
          to: formatted_destination_phone,
          link: link(capture_doc.request_token, session_uuid),
        )
      end

      def form_submit
        Idv::PhoneForm.new(previous_params: {}, user: current_user).submit(permit(:phone))
      end

      def formatted_destination_phone
        raw_phone = permit(:phone)[:phone]
        PhoneFormatter.format(raw_phone, country_code: 'US')
      end

      def update_document_capture_session_requested_at(session_uuid)
        return unless FeatureManagement.document_capture_step_enabled?
        document_capture_session = DocumentCaptureSession.find_by(uuid: session_uuid)
        return unless document_capture_session
        document_capture_session.update!(requested_at: Time.zone.now)
      end

      def link(token, session_uuid)
        if FeatureManagement.document_capture_step_enabled?
          idv_capture_doc_dashes_url('document-capture-session': session_uuid)
        else
          idv_capture_doc_dashes_url(token: token)
        end
      end

      def throttled_else_increment
        Throttler::IsThrottledElseIncrement.call(user_id, :idv_send_link)
      end
    end
  end
end
