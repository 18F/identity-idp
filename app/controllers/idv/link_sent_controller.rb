module Idv
  class LinkSentController < ApplicationController
    include IdvSession
    include IdvStepConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_upload_step_complete
    before_action :confirm_document_capture_needed

    def show
      analytics.idv_doc_auth_link_sent_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('link_sent', :view, true)

      render :show, locals: extra_view_variables
    end

    def update
      flow_session['redo_document_capture'] = nil # done with this redo

      analytics.idv_doc_auth_link_sent_submitted(analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('link_sent', :update, true)

      redirect_to idv_ssn_url
    end

    def extra_view_variables
      # Used to call :verify_document_status in idv/shared/_document_capture.html.erb
      # That code can be updated after the hybrid flow is out of the FSM, and then
      # this can be removed.
      @step_url = :idv_doc_auth_step_url

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
      return if flow_session['redo_document_capture']

      pii = flow_session['pii_from_doc'] # hash with indifferent access
      return if pii.blank? && !idv_session.verify_info_step_complete?

      redirect_to idv_ssn_url
    end

    def analytics_arguments
      {
        flow_path: flow_path,
        step: 'link_sent',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
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
      session[:in_person_cta_variant] = bucket
      {
        in_person_cta_variant_testing_enabled:
        IdentityConfig.store.in_person_cta_variant_testing_enabled,
        in_person_cta_variant_active: bucket,
      }
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
