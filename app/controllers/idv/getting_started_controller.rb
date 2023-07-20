module Idv
  class GettingStartedController < ApplicationController
    include IdvStepConcern

    before_action :confirm_agreement_needed

    def show
      analytics.idv_doc_auth_getting_started_visited(**analytics_arguments)

      # Register both Welcome and Agreement steps in DocAuthLog
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('welcome', :view, true)
      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
        call('agreement', :view, true)

      @sp_name = decorated_session.sp_name || APP_NAME
      @title = t('doc_auth.headings.getting_started', sp_name: @sp_name)

      render :show, locals: { flow_session: flow_session }
    end

    def update
      flow_session[:skip_upload_step] = true unless FeatureManagement.idv_allow_hybrid_flow?
      skip_to_capture if params[:skip_upload]

      result = Idv::ConsentForm.new.submit(consent_form_params)

      analytics.idv_doc_auth_getting_started_submitted(
        **analytics_arguments.merge(result.to_h),
      )

      if result.success?
        idv_session.idv_consent_given = true

        create_document_capture_session
        cancel_previous_in_person_enrollments

        redirect_to idv_hybrid_handoff_url
      else
        redirect_to idv_getting_started_url
      end
    end

    private

    def analytics_arguments
      {
        step: 'getting_started',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(ab_test_analytics_buckets)
    end

    def create_document_capture_session
      document_capture_session = DocumentCaptureSession.create(
        user_id: current_user.id,
        issuer: sp_session[:issuer],
      )
      flow_session[:document_capture_session_uuid] = document_capture_session.uuid
    end

    def cancel_previous_in_person_enrollments
      return unless IdentityConfig.store.in_person_proofing_enabled
      UspsInPersonProofing::EnrollmentHelper.
        cancel_stale_establishing_enrollments_for_user(current_user)
    end

    def skip_to_capture
      flow_session[:skip_upload_step] = true
      idv_session.flow_path = 'standard'
    end

    def consent_form_params
      params.require(:doc_auth).permit(:ial2_consent_given)
    end

    def confirm_agreement_needed
      return unless idv_session.idv_consent_given

      redirect_to idv_hybrid_handoff_url
    end
  end
end
