module Idv
  class AgreementController < ApplicationController
    include IdvSession
    include IdvStepConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :render_404_if_agreement_controller_disabled
    before_action :confirm_welcome_step_complete
    before_action :confirm_agreement_needed

    def show
      analytics.idv_doc_auth_agreement_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'agreement', :view,
        true
      )

      render :show, locals: { flow_session: flow_session }
    end

    def update
      analytics.idv_doc_auth_agreement_submitted(**analytics_arguments)

      # for the 50/50 state
      flow_session['Idv::Steps::AgreementStep'] = true

      skip_to_capture if params[:skip_upload]

      Idv::ConsentForm.new.submit(consent_form_params)

      idv_session.agreement_checked = true

      redirect_to idv_hybrid_handoff_url
    end

    private

    def analytics_arguments
      {
        step: 'agreement',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }
    end

    def skip_to_capture
      flow_session[:skip_upload_step] = true
      flow_session[:flow_path] = 'standard'
    end

    def consent_form_params
      params.require(:doc_auth).permit(:ial2_consent_given)
    end

    def confirm_welcome_step_complete
      return if flow_session['Idv::Steps::WelcomeStep']

      redirect_to idv_doc_auth_url
    end

    def confirm_agreement_needed
      return unless idv_session.agreement_checked

      redirect_to idv_hybrid_handoff_url
    end

    def render_404_if_agreement_controller_disabled
      render_not_found unless IdentityConfig.store.doc_auth_agreement_controller_enabled
    end
  end
end
