module Idv
  class DocumentCaptureController < ApplicationController
    include Idv::AvailabilityConcern
    include AcuantConcern
    include DocumentCaptureConcern
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited, except: [:update]
    before_action :confirm_step_allowed
    before_action :override_csp_to_allow_acuant

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
        flow_path: 'standard',
        sp_name: decorated_sp_session.sp_name,
        failure_to_proof_url: return_to_sp_failure_to_proof_url(step: 'document_capture'),
        skip_doc_auth: idv_session.skip_doc_auth,
        opted_in_to_in_person_proofing: idv_session.opted_in_to_in_person_proofing,
        doc_auth_selfie_capture: decorated_sp_session.selfie_required?,
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
                           !idv_session.selfie_check_required || idv_session.skip_hybrid_handoff
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

    def cancel_establishing_in_person_enrollments
      UspsInPersonProofing::EnrollmentHelper.
        cancel_stale_establishing_enrollments_for_user(current_user)
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'document_capture',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
        redo_document_capture: idv_session.redo_document_capture,
        skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
        selfie_check_required: idv_session.selfie_check_required,
      }.merge(ab_test_analytics_buckets)
    end

    def handle_stored_result
      if stored_result&.success? && selfie_requirement_met?
        save_proofing_components(current_user)
        extract_pii_from_doc(current_user, store_in_session: true)
        flash[:success] = t('doc_auth.headings.capture_complete')
        successful_response
      else
        extra = { stored_result_present: stored_result.present? }
        failure(I18n.t('doc_auth.errors.general.network_error'), extra)
      end
    end
  end
end
