module Idv
  class DocumentCaptureController < ApplicationController
    include AcuantConcern
    include DocumentCaptureConcern
    include IdvStepConcern
    include StepIndicatorConcern
    include PhoneQuestionAbTestConcern

    before_action :confirm_not_rate_limited, except: [:update]
    before_action :confirm_step_allowed
    before_action :confirm_verify_info_step_needed
    before_action :override_csp_to_allow_acuant

    def show
      analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('document_capture', :view, true)

      render :show, locals: extra_view_variables
    end

    def update
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
        phone_with_camera: idv_session.phone_with_camera,
      }.merge(
        acuant_sdk_upgrade_a_b_testing_variables,
        phone_question_ab_test_analytics_bucket,
      )
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :document_capture,
        controller: controller_name,
        next_steps: [:ssn], # :ipp_state_id
        preconditions: ->(idv_session:, user:) { idv_session.flow_path == 'standard' },
      )
    end

    private

    def confirm_hybrid_handoff_complete
      return if idv_session.flow_path.present?

      redirect_to idv_hybrid_handoff_url
    end

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
      }.merge(ab_test_analytics_buckets)
    end

    def handle_stored_result
      if stored_result&.success?
        save_proofing_components(current_user)
        extract_pii_from_doc(current_user, stored_result, store_in_session: true)
        flash[:success] = t('doc_auth.headings.capture_complete')
        successful_response
      else
        extra = { stored_result_present: stored_result.present? }
        failure(I18n.t('doc_auth.errors.general.network_error'), extra)
      end
    end
  end
end
