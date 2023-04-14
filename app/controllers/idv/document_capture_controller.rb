module Idv
  class DocumentCaptureController < ApplicationController
    include IdvSession
    include IdvStepConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_upload_step_complete
    before_action :confirm_document_capture_needed
    before_action :override_document_capture_step_csp

    def show
      increment_step_counts

      analytics.idv_doc_auth_document_capture_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('document_capture', :view, true)

      render :show, locals: extra_view_variables
    end

    def update
      handle_stored_result

      analytics.idv_doc_auth_document_capture_submitted(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('document_capture', :update, true)

      redirect_to idv_ssn_url
    end

    def extra_view_variables
      url_builder = ImageUploadPresignedUrlGenerator.new

      {
        flow_session: flow_session,
        flow_path: 'standard',
        sp_name: decorated_session.sp_name,
        failure_to_proof_url: return_to_sp_failure_to_proof_url(step: 'document_capture'),

        front_image_upload_url: url_builder.presigned_image_upload_url(
          image_type: 'front',
          transaction_id: flow_session[:document_capture_session_uuid],
        ),
        back_image_upload_url: url_builder.presigned_image_upload_url(
          image_type: 'back',
          transaction_id: flow_session[:document_capture_session_uuid],
        ),
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
      pii = flow_session['pii_from_doc'] # hash with indifferent access
      return if pii.blank? && !idv_session.verify_info_step_complete?

      redirect_to idv_ssn_url
    end

    # This is copied from DocumentCaptureConcern, with out the step check
    def override_document_capture_step_csp
      policy = current_content_security_policy
      policy.connect_src(*policy.connect_src, 'us.acas.acuant.net')
      policy.script_src(*policy.script_src, :unsafe_eval)
      policy.style_src(*policy.style_src, :unsafe_inline)
      policy.img_src(*policy.img_src, 'blob:')
      request.content_security_policy = policy
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'document_capture',
        step_count: current_flow_step_counts['Idv::Steps::DocumentCaptureStep'],
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end

    def current_flow_step_counts
      user_session['idv/doc_auth_flow_step_counts'] ||= {}
      user_session['idv/doc_auth_flow_step_counts'].default = 0
      user_session['idv/doc_auth_flow_step_counts']
    end

    def increment_step_counts
      current_flow_step_counts['Idv::Steps::DocumentCaptureStep'] += 1
    end

    def acuant_sdk_upgrade_a_b_testing_variables
      bucket = AbTests::ACUANT_SDK.bucket(flow_session[:document_capture_session_uuid])
      testing_enabled = IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_enabled
      use_alternate_sdk = (bucket == :use_alternate_sdk)
      if use_alternate_sdk
        acuant_version = IdentityConfig.store.idv_acuant_sdk_version_alternate
      else
        acuant_version = IdentityConfig.store.idv_acuant_sdk_version_default
      end
      {
        acuant_sdk_upgrade_a_b_testing_enabled:
            testing_enabled,
        use_alternate_sdk: use_alternate_sdk,
        acuant_version: acuant_version,
      }
    end

    def in_person_cta_variant_testing_variables
      bucket = AbTests::IN_PERSON_CTA.bucket(flow_session[:document_capture_session_uuid])
      {
        in_person_cta_variant_testing_enabled:
        IdentityConfig.store.in_person_cta_variant_testing_enabled,
        in_person_cta_variant_active: bucket,
      }
    end

    def handle_stored_result
      if stored_result&.success?
        save_proofing_components
        extract_pii_from_doc(stored_result, store_in_session: !hybrid_flow_mobile?)
      else
        extra = { stored_result_present: stored_result.present? }
        failure(I18n.t('doc_auth.errors.general.network_error'), extra)
      end
    end

    def stored_result
      return @stored_result if defined?(@stored_result)
      @stored_result = document_capture_session&.load_result
    end

    def save_proofing_components
      return unless current_user

      doc_auth_vendor = DocAuthRouter.doc_auth_vendor(
        discriminator: flow_session[document_capture_session_uuid_key],
        analytics: analytics,
      )

      component_attributes = {
        document_check: doc_auth_vendor,
        document_type: 'state_id',
      }
      ProofingComponent.create_or_find_by(user: current_user).update(component_attributes)
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

    # copied from Flow::Failure module
    def failure(message, extra = nil)
      flow_session[:error_message] = message
      form_response_params = { success: false, errors: { message: message } }
      form_response_params[:extra] = extra unless extra.nil?
      FormResponse.new(**form_response_params)
    end
  end
end
