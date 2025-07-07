# frozen_string_literal: true

module Idv
  class HybridHandoffController < ApplicationController
    include Idv::AvailabilityConcern
    include ActionView::Helpers::DateHelper
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_step_allowed
    before_action :confirm_hybrid_handoff_needed, only: :show

    def show
      abandon_any_ipp_progress
      @upload_enabled = upload_enabled?

      @direct_ipp_with_selfie_enabled = IdentityConfig.store.in_person_doc_auth_button_enabled &&
                                        Idv::InPersonConfig.enabled_for_issuer?(
                                          decorated_sp_session.sp_issuer,
                                        )
      @post_office_enabled = IdentityConfig.store.in_person_proofing_enabled &&
                             IdentityConfig.store.in_person_proofing_opt_in_enabled &&
                             IdentityConfig.store.in_person_doc_auth_button_enabled
      @selfie_required = idv_session.selfie_check_required
      @idv_how_to_verify_form = Idv::HowToVerifyForm.new
      set_how_to_verify_presenter

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'upload', :view,
        true
      )
      analytics.idv_doc_auth_hybrid_handoff_visited(**analytics_arguments)
      # reset if we visit or come back
      idv_session.skip_doc_auth_from_handoff = nil

      render :show, locals: extra_view_variables
    end

    def update
      clear_future_steps!
      abandon_any_ipp_progress

      if how_to_verify_form_params['selection'] == Idv::HowToVerifyForm::IPP
        idv_session.opted_in_to_in_person_proofing = true
        idv_session.flow_path = 'standard'
        idv_session.skip_doc_auth_from_how_to_verify = true
        redirect_to idv_document_capture_url(step: :hybrid_handoff)
      elsif params[:type] == 'mobile'
        handle_phone_submission
      else
        doc_auth_mock_upload if upload_enabled?
        bypass_send_link_steps
      end
    end

    def self.selected_remote(idv_session:)
      if IdentityConfig.store.in_person_proofing_opt_in_enabled &&
         IdentityConfig.store.in_person_proofing_enabled &&
         idv_session.service_provider&.in_person_proofing_enabled
        idv_session.skip_doc_auth_from_how_to_verify == false
      else
        idv_session.skip_doc_auth_from_how_to_verify.nil? ||
          idv_session.skip_doc_auth_from_how_to_verify == false
      end
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :hybrid_handoff,
        controller: self,
        next_steps: [:choose_id_type, :link_sent, :document_capture, :socure_document_capture],
        preconditions: ->(idv_session:, user:) do
          idv_session.idv_consent_given? &&
          (self.selected_remote(idv_session: idv_session) || # from opt-in screen
            # back from ipp doc capture screen
            idv_session.skip_doc_auth_from_handoff)
        end,
        undo_step: ->(idv_session:, user:) do
          idv_session.flow_path = nil
          idv_session.phone_for_mobile_flow = nil
        end,
      )
    end

    private

    def mobile_required?
      idv_session.selfie_check_required ||
        document_capture_session.doc_auth_vendor == Idp::Constants::Vendors::SOCURE
    end

    def set_how_to_verify_presenter
      @presenter = Idv::HowToVerifyPresenter.new(
        mobile_required: mobile_required?,
        selfie_check_required: @selfie_required,
        passport_allowed: idv_session.passport_allowed,
      )
    end

    def abandon_any_ipp_progress
      current_user&.establishing_in_person_enrollment&.cancel
    end

    def handle_phone_submission
      return rate_limited_failure if rate_limiter.limited?
      rate_limiter.increment!
      idv_session.phone_for_mobile_flow = formatted_destination_phone
      idv_session.flow_path = 'hybrid'
      telephony_result = send_link
      telephony_form_response = build_telephony_form_response(telephony_result)

      if !telephony_result.success?
        failure(telephony_form_response.errors[:message])
      end

      if telephony_result.success?
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

    def upload_enabled?
      idv_session.desktop_selfie_test_mode_enabled?
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
      redirect_to next_step

      analytics.idv_doc_auth_hybrid_handoff_submitted(
        **analytics_arguments.merge(
          form_response(destination: :document_capture).to_h,
        ),
      )
    end

    def next_step
      if idv_session.passport_allowed
        idv_choose_id_type_url
      else
        idv_document_capture_url
      end
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
        redo_document_capture: params[:redo] ? true : nil,
        skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
        selfie_check_required: idv_session.selfie_check_required,
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
      # TODO: Attempts API PII Add phone_number: formatted_destination_phone,
      attempts_api_tracker.idv_rate_limited(
        limiter_type: :idv_send_link,
      )
      message = I18n.t(
        'doc_auth.errors.send_link_limited',
        timeout: distance_of_time_in_words(
          Time.zone.now,
          [rate_limiter.expires_at, Time.zone.now].compact.max,
          except: :seconds,
        ),
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

    def formatted_destination_phone
      raw_phone = params.require(:doc_auth).permit(:phone)
      PhoneFormatter.format(raw_phone, country_code: 'US')
    end

    def how_to_verify_form_params
      params.require(:idv_how_to_verify_form).permit(:selection, selection: [])
    rescue ActionController::ParameterMissing
      ActionController::Parameters.new(selection: [])
    end

    def doc_auth_mock_upload
      if IdentityConfig.store.doc_auth_mock_upload_enabled
        document_capture_session.update(doc_auth_vendor: Idp::Constants::Vendors::MOCK)
      end
    end
  end
end
