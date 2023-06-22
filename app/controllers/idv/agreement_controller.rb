module Idv
  class AgreementController < ApplicationController
    include IdvSession
    include IdvStepConcern
    include OutageConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :confirm_welcome_step_complete
    before_action :confirm_agreement_needed
    before_action :check_for_outage, only: :show

    def show
      analytics.idv_doc_auth_agreement_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'agreement', :view,
        true
      )

      render :show, locals: { flow_session: flow_session }
    end

    def update
      skip_to_capture if params[:skip_upload]

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
      return if idv_session.welcome_visited

      if IdentityConfig.store.doc_auth_welcome_controller_enabled
        redirect_to idv_welcome_url
      else
        redirect_to idv_doc_auth_url
      end
    end

    def confirm_agreement_needed
      return unless idv_session.idv_consent_given

      redirect_to idv_hybrid_handoff_url
    end
  end
end
