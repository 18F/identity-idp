module Idv
  module Steps
    class SendLinkStep < DocAuthBaseStep
      include ActionView::Helpers::DateHelper

      STEP_INDICATOR_STEP = :verify_id

      def self.analytics_visited_event
        :idv_doc_auth_send_link_visited
      end

      def self.analytics_submitted_event
        :idv_doc_auth_send_link_submitted
      end

      def call
        return throttled_failure if throttle.throttled_else_increment?
        telephony_result = send_link
        failure_reason = nil
        if !telephony_result.success?
          failure_reason = { telephony: [telephony_result.error.class.name.demodulize] }
        end
        @flow.irs_attempts_api_tracker.idv_phone_upload_link_sent(
          success: telephony_result.success?,
          phone_number: formatted_destination_phone,
          failure_reason: failure_reason,
        )
        build_telephony_form_response(telephony_result)
      end

      private

      def build_telephony_form_response(telephony_result)
        FormResponse.new(
          success: telephony_result.success?,
          errors: { message: telephony_result.error&.friendly_message },
          extra: { telephony_response: telephony_result.to_h },
        )
      end

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

        @flow.irs_attempts_api_tracker.idv_phone_send_link_rate_limited(
          phone_number: formatted_destination_phone,
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
        params = permit(:phone)
        params[:otp_delivery_preference] = 'sms'
        Idv::PhoneForm.new(
          previous_params: {},
          user: current_user,
          delivery_methods: [:sms],
        ).submit(params)
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
        )
      end

      def link(session_uuid)
        idv_capture_doc_dashes_url(
          'document-capture-session': session_uuid,
          request_id: sp_session[:request_id],
        )
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
