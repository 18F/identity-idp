module Idv
  class AgreementController < ApplicationController
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_welcome_step_complete
    before_action :confirm_agreement_needed

    def show
      analytics.idv_doc_auth_agreement_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'agreement', :view,
        true
      )
    end

    def update
      skip_to_capture if params[:skip_hybrid_handoff]

      result = Idv::ConsentForm.new.submit(consent_form_params)

      analytics.idv_doc_auth_agreement_submitted(
        **analytics_arguments.merge(result.to_h),
      )

      next_url = IdentityConfig.store.in_person_proofing_opt_in_enabled ? idv_remote_or_in_person_url : idv_hybrid_handoff_url
      puts('feature flag is: ' + IdentityConfig.store.in_person_proofing_opt_in_enabled.to_s)
      puts "next url is: " + next_url

      if result.success?
        idv_session.idv_consent_given = true

        redirect_to next_url
      else
        redirect_to idv_agreement_url
      end
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

    def confirm_welcome_step_complete
      return if idv_session.welcome_visited

      redirect_to idv_welcome_url
    end

    def confirm_agreement_needed
      return unless idv_session.idv_consent_given

      redirect_to idv_hybrid_handoff_url
    end
  end
end
