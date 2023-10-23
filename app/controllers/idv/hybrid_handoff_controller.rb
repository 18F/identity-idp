module Idv
  class HybridHandoffController < ApplicationController
    include ActionView::Helpers::DateHelper
    include IdvStepConcern
    include StepIndicatorConcern
    include PhoneQuestionAbTestConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_verify_info_step_needed
    before_action :confirm_hybrid_handoff_allowed
    before_action :setup_for_redo, only: :show
    before_action :confirm_hybrid_handoff_needed, only: :show
    before_action :maybe_redirect_for_phone_question_ab_test, only: :show

    def show
      analytics.idv_doc_auth_hybrid_handoff_visited(**analytics_arguments)

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

      if params[:type] == 'mobile'
        handle_phone_submission
      else
        bypass_send_link_steps
      end
    end

    def navigation_step
      Idv::StepInfo.new(
        controller: self.class.controller_name,
        next_steps: [:link_sent, :document_capture],
        requirements: ->(idv_session:, user:) { idv_session.idv_consent_given },
      )
    end

    # private

    def handle_phone_submission
      return rate_limited_failure if rate_limiter.limited?
      rate_limiter.increment!
      idv_session.phone_for_mobile_flow = formatted_destination_phone
      idv_session.flow_path = 'hybrid'
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
        idv_session.flow_path = nil
      end

      analytics.idv_doc_auth_hybrid_handoff_submitted(
        **analytics_arguments.merge(telephony_form_response.to_h),
      )
    end

    def send_link
      session_uuid = idv_session.document_capture_session_uuid
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
          flow_path: idv_session.flow_path,
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
      idv_session.flow_path = 'standard'
      redirect_to idv_document_capture_url

      analytics.idv_doc_auth_hybrid_handoff_submitted(
        **analytics_arguments.merge(
          form_response(destination: :document_capture).to_h,
        ),
      )
    end

    def extra_view_variables
      { idv_phone_form: build_form }
    end

    def build_form
      Idv::PhoneForm.new(
        previous_params: {},
        user: current_user,
        delivery_methods: [:sms],
      )
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: current_user,
        rate_limit_type: :idv_send_link,
      )
    end

    def analytics_arguments
      {
        step: 'hybrid_handoff',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
        redo_document_capture: params[:redo] ? true : nil,
        skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
      }.merge(ab_test_analytics_buckets)
    end

    def form_response(destination:)
      FormResponse.new(
        success: true,
        errors: {},
        extra: {
          destination: destination,
          flow_path: idv_session.flow_path,
        },
      )
    end

    def rate_limited_failure
      analytics.rate_limit_reached(
        limiter_type: :idv_send_link,
      )
      message = I18n.t(
        'errors.doc_auth.send_link_limited',
        timeout: distance_of_time_in_words(
          Time.zone.now,
          [rate_limiter.expires_at, Time.zone.now].compact.max,
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
      flash[:error] = message
      form_response_params = { success: false, errors: { message: message } }
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
    end

    def confirm_hybrid_handoff_allowed
      return if step_allowed?(:hybrid_handoff)

      redirect_to idv_agreement_url
    end

    def setup_for_redo
      return unless params[:redo]

      idv_session.redo_document_capture = true
      idv_session.flow_path = nil
    end

    def confirm_hybrid_handoff_needed
      if idv_session.skip_hybrid_handoff?
        # We previously skipped hybrid handoff. Keep doing that.
        idv_session.flow_path = 'standard'
      end

      if !FeatureManagement.idv_allow_hybrid_flow?
        # When hybrid flow is unavailable, skip it.
        # But don't store that we skipped it in idv_session, in case it is back to
        # available when the user tries to redo document capture.
        idv_session.flow_path = 'standard'
      end

      return if idv_session.flow_path.blank?

      if idv_session.flow_path == 'standard'
        redirect_to idv_document_capture_url
      elsif idv_session.flow_path == 'hybrid'
        redirect_to idv_link_sent_url
      end
    end

    def formatted_destination_phone
      raw_phone = params.require(:doc_auth).permit(:phone)
      PhoneFormatter.format(raw_phone, country_code: 'US')
    end
  end
end
