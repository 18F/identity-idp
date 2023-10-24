module Idv
  class AgreementController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_agreement_step_allowed
    before_action :confirm_document_capture_not_complete

    def show
      analytics.idv_doc_auth_agreement_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'agreement', :view,
        true
      )

      @consent_form = Idv::ConsentForm.new(
        idv_consent_given: idv_session.idv_consent_given,
      )
    end

    def update
      skip_to_capture if params[:skip_hybrid_handoff]

      result = Idv::ConsentForm.new.submit(consent_form_params)

      analytics.idv_doc_auth_agreement_submitted(
        **analytics_arguments.merge(result.to_h),
      )

      if result.success?
        idv_session.idv_consent_given = true

        redirect_to idv_hybrid_handoff_url
      else
        redirect_to idv_agreement_url
      end
    end

    def self.navigation_step
      Idv::StepInfo.new(
        controller: controller_name,
        next_steps: [:hybrid_handoff, :document_capture, :phone_question],
        requirements: ->(idv_session:, user:) { idv_session.welcome_visited },
      )
    end

    private

    def analytics_arguments
      {
        step: 'agreement',
        analytics_id: 'Doc Auth',
        skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
        irs_reproofing: irs_reproofing?,
      }.merge(ab_test_analytics_buckets)
    end

    def skip_to_capture
      idv_session.flow_path = 'standard'

      # Store that we're skipping hybrid handoff so if the user
      # tries to redo document capture they can skip it then too.
      idv_session.skip_hybrid_handoff = true
    end

    def consent_form_params
      params.require(:doc_auth).permit(:idv_consent_given)
    end

    def confirm_agreement_step_allowed
      return if step_allowed?(:agreement)

      redirect_to path_for_latest_step
    end
  end
end
