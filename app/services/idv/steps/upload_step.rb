module Idv
  module Steps
    class UploadStep < DocAuthBaseStep
      include ActionView::Helpers::DateHelper
      STEP_INDICATOR_STEP = :verify_id

      def self.analytics_visited_event
        :idv_doc_auth_upload_visited
      end

      def self.analytics_submitted_event
        :idv_doc_auth_upload_submitted
      end

      def call
        # See the simple_form_for in
        # app/views/idv/doc_auth/upload.html.erb
        if hybrid_flow_chosen?
          handle_phone_submission
        else
          bypass_send_link_steps
        end
      end

      def hybrid_flow_chosen?
        params[:type] != 'desktop' && !mobile_device?
      end

      def extra_view_variables
        { idv_phone_form: build_form }
      end

      def link_for_send_link(session_uuid)
        idv_hybrid_mobile_entry_url(
          'document-capture-session': session_uuid,
          request_id: sp_session[:request_id],
        )
      end

      private

      def build_form
        Idv::PhoneForm.new(
          previous_params: {},
          user: current_user,
          delivery_methods: [:sms],
        )
      end

      def form_submit
        return super unless params[:type] == 'mobile'

        params = permit(:phone)
        params[:otp_delivery_preference] = 'sms'
        build_form.submit(params)
      end

      def handle_phone_submission
        throttle.increment!
        return throttled_failure if throttle.throttled?
        idv_session[:phone_for_mobile_flow] = permit(:phone)[:phone]
        flow_session[:phone_for_mobile_flow] = idv_session[:phone_for_mobile_flow]
        telephony_result = send_link
        failure_reason = nil
        if !telephony_result.success?
          failure_reason = { telephony: [telephony_result.error.class.name.demodulize] }
        end

        if !failure_reason
          flow_session[:flow_path] = 'hybrid'
          redirect_to idv_link_sent_url
        end

        build_telephony_form_response(telephony_result)
      end

      def identity
        current_user&.identities&.order('created_at DESC')&.first
      end

      def link
        identity&.return_to_sp_url || root_url
      end

      def application
        identity&.friendly_name || APP_NAME
      end

      def bypass_send_link_steps
        flow_session[:flow_path] = 'standard'
        redirect_to idv_document_capture_url

        form_response(destination: :document_capture)
      end

      def throttle
        @throttle ||= Throttle.new(
          user: current_user,
          throttle_type: :idv_send_link,
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

        failure(message)
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

      def sp_or_app_name
        current_sp&.friendly_name.presence || APP_NAME
      end

      def send_link
        session_uuid = flow_session[:document_capture_session_uuid]
        update_document_capture_session_requested_at(session_uuid)
        Telephony.send_doc_auth_link(
          to: formatted_destination_phone,
          link: link_for_send_link(session_uuid),
          country_code: Phonelib.parse(formatted_destination_phone).country,
          sp_or_app_name: sp_or_app_name,
        )
      end

      def build_telephony_form_response(telephony_result)
        FormResponse.new(
          success: telephony_result.success?,
          errors: { message: telephony_result.error&.friendly_message },
          extra: {
            telephony_response: telephony_result.to_h,
            destination: :link_sent,
          },
        )
      end

      def mobile_device?
        # See app/javascript/packs/document-capture-welcome.js
        # And app/services/idv/steps/agreement_step.rb
        !!flow_session[:skip_upload_step]
      end

      def form_response(destination:)
        FormResponse.new(
          success: true,
          errors: {},
          extra: {
            destination: destination,
            skip_upload_step: mobile_device?,
          },
        )
      end
    end
  end
end
