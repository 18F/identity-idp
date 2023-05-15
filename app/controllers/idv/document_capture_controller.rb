module Idv
  class DocumentCaptureController < ApplicationController
    include AcuantConcern
    include DocumentCaptureConcern
    include IdvSession
    include IdvStepConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_upload_step_complete
    before_action :confirm_document_capture_needed
    before_action :override_csp_to_allow_acuant

    def show
      analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('document_capture', :view, true)

      render :show, locals: extra_view_variables
    end

    def update
      flow_session['redo_document_capture'] = nil # done with this redo
      result = handle_stored_result
      analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('document_capture', :update, true)

      if result.success?
        redirect_to idv_ssn_url
      else
        redirect_to idv_document_capture_url
      end
    end

    def extra_view_variables
      {
        document_capture_session_uuid: flow_session[:document_capture_session_uuid],
        flow_path: 'standard',
        sp_name: decorated_session.sp_name,
        failure_to_proof_url: return_to_sp_failure_to_proof_url(step: 'document_capture'),
      }.merge(
        acuant_sdk_upgrade_a_b_testing_variables,
        in_person_cta_variant_testing_variables,
      )
    end

    private

    def confirm_upload_step_complete
      return if flow_session['Idv::Steps::UploadStep']

      redirect_to idv_doc_auth_url
    end

    def confirm_document_capture_needed
      return if flow_session['redo_document_capture']

      pii = flow_session['pii_from_doc'] # hash with indifferent access
      return if pii.blank? && !idv_session.verify_info_step_complete?

      redirect_to idv_ssn_url
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'document_capture',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end

    def in_person_cta_variant_testing_variables
      bucket = AbTests::IN_PERSON_CTA.bucket(flow_session[:document_capture_session_uuid])
      session[:in_person_cta_variant] = bucket
      {
        in_person_cta_variant_testing_enabled:
        IdentityConfig.store.in_person_cta_variant_testing_enabled,
        in_person_cta_variant_active: bucket,
      }
    end

    def handle_stored_result
      if stored_result&.success?
        save_proofing_components # not tested in current controller spec
        extract_pii_from_doc(stored_result, store_in_session: !hybrid_flow_mobile?)
        flash[:success] = t('doc_auth.headings.capture_complete')
        successful_response
      else
        extra = { stored_result_present: stored_result.present? }
        failure(I18n.t('doc_auth.errors.general.network_error'), extra)
      end
    end

    def stored_result
      return @stored_result if defined?(@stored_result)
      @stored_result = document_capture_session&.load_result
    end

    def hybrid_flow_mobile?
      user_id_from_token.present?
    end

    def user_id_from_token
      flow_session[:doc_capture_user_id]
    end

    # copied from doc_auth_base_step.rb
    # @param [DocAuth::Response,
    #   DocumentCaptureSessionAsyncResult,
    #   DocumentCaptureSessionResult] response
    def extract_pii_from_doc(response, store_in_session: false)
      # controller test is not hitting this ... perhaps in feature test
      pii_from_doc = response.pii_from_doc.merge(
        uuid: effective_user.uuid,
        phone: effective_user.phone_configurations.take&.phone,
        uuid_prefix: ServiceProvider.find_by(issuer: sp_session[:issuer])&.app_id,
      )

      flow_session[:had_barcode_read_failure] = response.attention_with_barcode?
      if store_in_session
        flow_session[:pii_from_doc] ||= {}
        flow_session[:pii_from_doc].merge!(pii_from_doc)
        idv_session.clear_applicant!
      end
      track_document_state(pii_from_doc[:state])
    end

    def track_document_state(state)
      return unless IdentityConfig.store.state_tracking_enabled && state
      doc_auth_log = DocAuthLog.find_by(user_id: current_user.id)
      return unless doc_auth_log
      doc_auth_log.state = state
      doc_auth_log.save!
    end

    def successful_response
      FormResponse.new(success: true)
    end

    # copied from Flow::Failure module
    def failure(message, extra = nil)
      flow_session[:error_message] = message
      form_response_params = { success: false, errors: { message: message } }
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
    end
  end
end
