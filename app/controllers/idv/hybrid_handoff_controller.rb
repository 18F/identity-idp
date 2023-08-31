module Idv
  class HybridHandoffController < ApplicationController
    include ActionView::Helpers::DateHelper
    include IdvSession
    include IdvStepConcern
    include OutageConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_agreement_step_complete
    before_action :confirm_hybrid_handoff_needed, only: :show
    before_action :check_for_outage, only: :show

    def show
      analytics.idv_doc_auth_upload_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'upload', :view,
        true
      )

      render :show, locals: extra_view_variables
    end

    def update
      irs_attempts_api_tracker.idv_document_upload_method_selected(
        upload_method: params[:type],
      )

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

    def handle_phone_submission
      throttle.increment!
      return throttled_failure if throttle.throttled?
      idv_session.phone_for_mobile_flow = params[:doc_auth][:phone]
      flow_session[:flow_path] = 'hybrid'
      telephony_result = send_link
      telephony_form_response = build_telephony_form_response(telephony_result)

      failure_reason = nil
      if !telephony_result.success?
        failure_reason = { telephony: [telephony_result.error.class.name.demodulize] }
        failure(telephony_form_response.errors[:message])
      end
      irs_attempts_api_tracker.idv_phone_upload_link_sent(
        success: telephony_result.success?,
        phone_number: formatted_destination_phone,
        failure_reason: failure_reason,
      )

      if !failure_reason
        redirect_to idv_link_sent_url
      else
        redirect_to idv_hybrid_handoff_url
        flow_session[:flow_path] = nil
      end

      analytics.idv_doc_auth_upload_submitted(
        **analytics_arguments.merge(telephony_form_response.to_h),
      )
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

    def link_for_send_link(session_uuid)
      idv_hybrid_mobile_entry_url(
        'document-capture-session': session_uuid,
        request_id: sp_session[:request_id],
      )
    end

    def sp_or_app_name
      current_sp&.friendly_name.presence || APP_NAME
    end

    def build_telephony_form_response(telephony_result)
      FormResponse.new(
        success: telephony_result.success?,
        errors: { message: telephony_result.error&.friendly_message },
        extra: {
          telephony_response: telephony_result.to_h,
          destination: :link_sent,
          flow_path: flow_session[:flow_path],
        },
      )
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

    def bypass_send_link_steps
      flow_session[:flow_path] = 'standard'
      redirect_to idv_document_capture_url

      analytics.idv_doc_auth_upload_submitted(
        **analytics_arguments.merge(
          form_response(destination: :document_capture).to_h,
        ),
      )
    end

    def extra_view_variables
      {
        flow_session: flow_session,
        idv_phone_form: build_form,
      }
    end

    def mobile_device?
      # See app/javascript/packs/document-capture-welcome.js
      # And app/services/idv/steps/agreement_step.rb
      !!flow_session[:skip_upload_step]
    end

    def build_form
      Idv::PhoneForm.new(
        previous_params: {},
        user: current_user,
        delivery_methods: [:sms],
      )
    end

    def throttle
      @throttle ||= Throttle.new(
        user: current_user,
        throttle_type: :idv_send_link,
      )
    end

    def analytics_arguments
      {
        step: 'upload',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end

    def form_response(destination:)
      FormResponse.new(
        success: true,
        errors: {},
        extra: {
          destination: destination,
          skip_upload_step: mobile_device?,
          flow_path: flow_session[:flow_path],
        },
      )
    end

    def throttled_failure
      analytics.throttler_rate_limit_triggered(
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

      irs_attempts_api_tracker.idv_phone_send_link_rate_limited(
        phone_number: formatted_destination_phone,
      )

      failure(message)
      redirect_to idv_hybrid_handoff_url
    end

    # copied from Flow::Failure module
    def failure(message, extra = nil)
      flow_session[:error_message] = message
      form_response_params = { success: false, errors: { message: message } }
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
    end

    def confirm_agreement_step_complete
      return if flow_session['Idv::Steps::AgreementStep']

      redirect_to idv_doc_auth_url
    end

    def confirm_hybrid_handoff_needed
      return if !flow_session[:flow_path]

      if flow_session[:flow_path] == 'standard'
        redirect_to idv_document_capture_url
      elsif flow_session[:flow_path] == 'hybrid'
        redirect_to idv_link_sent_url
      end
    end

    def formatted_destination_phone
      raw_phone = params.require(:doc_auth).permit(:phone)
      PhoneFormatter.format(raw_phone, country_code: 'US')
    end
  end
end
