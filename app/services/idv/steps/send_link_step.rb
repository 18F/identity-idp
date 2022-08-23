module Idv
  module Steps
    class SendLinkStep < DocAuthBaseStep
      include ActionView::Helpers::DateHelper

      STEP_INDICATOR_STEP = :verify_id

      def call
        return throttled_failure if throttle.throttled_else_increment?
        telephony_result = send_link
        @flow.irs_attempts_api_tracker.idv_phone_upload_link_sent(
          success: telephony_result.success?,
          phone_number: formatted_destination_phone,
        )
        return failure(telephony_result.error.friendly_message) unless telephony_result.success?
      end

      private

      def throttled_failure
        @flow.analytics.throttler_rate_limit_triggered(
          throttle_type: :idv_send_link,
        )
        message = I18n.t(
          'errors.doc_auth.send_link_throttle',
          timeout: distance_of_time_in_words(
            Time.zone.now,
            [throttle.expires_at, Time.zone.now].compact.max,
            except: :seconds,
          ),
        )
        failure(message)
      end

      def send_link
        session_uuid = flow_session[:document_capture_session_uuid]
        update_document_capture_session_requested_at(session_uuid)
        Telephony.send_doc_auth_link(
          to: formatted_destination_phone,
          link: link(session_uuid),
          country_code: Phonelib.parse(formatted_destination_phone).country,
        )
      end

      def form_submit
        Idv::PhoneForm.new(
          previous_params: {},
          user: current_user,
          delivery_methods: [:sms],
        ).submit(permit(:phone))
      end

      def formatted_destination_phone
        raw_phone = permit(:phone)[:phone]
        PhoneFormatter.format(raw_phone, country_code: 'US')
      end

      def update_document_capture_session_requested_at(session_uuid)
        document_capture_session = DocumentCaptureSession.find_by(uuid: session_uuid)
        return unless document_capture_session
        document_capture_session.update!(
          requested_at: Time.zone.now,
          cancelled_at: nil,
          issuer: sp_session[:issuer],
          ial2_strict: sp_session[:ial2_strict],
        )
      end

      def link(session_uuid)
        idv_capture_doc_dashes_url('document-capture-session': session_uuid)
      end

      def throttle
        @throttle ||= Throttle.new(
          user: current_user,
          throttle_type: :idv_send_link,
        )
      end
    end
  end
end
