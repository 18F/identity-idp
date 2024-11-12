# frozen_string_literal: true

module Idv
  class DocumentCaptureController < ApplicationController
    include Idv::AvailabilityConcern
    include AcuantConcern
    include DocumentCaptureConcern
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited, except: [:update]
    before_action :confirm_step_allowed, unless: -> { allow_direct_ipp? }
    before_action :override_csp_to_allow_acuant
    before_action :set_usps_form_presenter
    before_action -> { redirect_to_correct_vendor(Idp::Constants::Vendors::LEXIS_NEXIS, false) }

    def show
      analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('document_capture', :view, true)

      render :show, locals: extra_view_variables
    end

    def update
      clear_future_steps!
      idv_session.redo_document_capture = nil # done with this redo
      # Not used in standard flow, here for data consistency with hybrid flow.
      document_capture_session.confirm_ocr

      result = handle_stored_result
      analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('document_capture', :update, true)

      cancel_establishing_in_person_enrollments

      if result.success?
        redirect_to idv_ssn_url
      else
        redirect_to idv_document_capture_url
      end
    end

    def extra_view_variables
      {
        document_capture_session_uuid: document_capture_session_uuid,
        mock_client: doc_auth_vendor == 'mock',
        flow_path: 'standard',
        sp_name: decorated_sp_session.sp_name,
        failure_to_proof_url: return_to_sp_failure_to_proof_url(step: 'document_capture'),
        skip_doc_auth: idv_session.skip_doc_auth,
        skip_doc_auth_from_how_to_verify: idv_session.skip_doc_auth_from_how_to_verify,
        skip_doc_auth_from_handoff: idv_session.skip_doc_auth_from_handoff,
        opted_in_to_in_person_proofing: idv_session.opted_in_to_in_person_proofing,
        doc_auth_selfie_capture: resolved_authn_context_result.facial_match?,
      }.merge(
        acuant_sdk_upgrade_a_b_testing_variables,
      )
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :document_capture,
        controller: self,
        next_steps: [:ssn, :ipp_ssn], # :ipp_state_id
        preconditions: ->(idv_session:, user:) {
                         idv_session.flow_path == 'standard' && (
                           # mobile
                           idv_session.skip_doc_auth_from_handoff ||
                           idv_session.skip_hybrid_handoff ||
                            idv_session.skip_doc_auth ||
                            idv_session.skip_doc_auth_from_how_to_verify ||
                            !idv_session.selfie_check_required || # desktop but selfie not required
                             idv_session.desktop_selfie_test_mode_enabled?
                         )
                       },
        undo_step: ->(idv_session:, user:) do
          idv_session.pii_from_doc = nil
          idv_session.invalidate_in_person_pii_from_user!
          idv_session.had_barcode_attention_error = nil
          idv_session.had_barcode_read_failure = nil
          idv_session.selfie_check_performed = nil
        end,
      )
    end

    private

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'document_capture',
        analytics_id: 'Doc Auth',
        redo_document_capture: idv_session.redo_document_capture,
        skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
        liveness_checking_required: resolved_authn_context_result.facial_match?,
        selfie_check_required: resolved_authn_context_result.facial_match?,
      }.merge(ab_test_analytics_buckets)
    end

    def allow_direct_ipp?
      return false unless idv_session.welcome_visited &&
                          idv_session.idv_consent_given?
      # not allowed when no step param and action:show(get request)
      return false if params[:step].blank? || params[:action].to_s != 'show' ||
                      idv_session.flow_path == 'hybrid'
      # Only allow direct access to document capture if IPP available
      return false unless IdentityConfig.store.in_person_doc_auth_button_enabled &&
                          Idv::InPersonConfig.enabled_for_issuer?(decorated_sp_session.sp_issuer)
      @previous_step_url = params[:step] == 'hybrid_handoff' ? idv_hybrid_handoff_path : nil
      # allow
      idv_session.flow_path = 'standard'
      idv_session.skip_doc_auth_from_handoff = true
      idv_session.skip_hybrid_handoff = nil
      true
    end

    def set_usps_form_presenter
      @presenter = Idv::InPerson::UspsFormPresenter.new
    end
  end
end
