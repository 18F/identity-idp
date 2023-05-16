module Idv
  class HybridHandoffController < ApplicationController
    include IdvSession
    include IdvStepConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :render_404_if_hybrid_handoff_controller_disabled
    before_action :confirm_agreement_step_complete

    def show
      analytics.idv_doc_auth_upload_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'upload', :view,
        true
      )

      render :show, locals: extra_view_variables
    end

    def extra_view_variables
      {
        flow_session: flow_session,
        idv_phone_form: build_form
      }
    end

    def build_form
      Idv::PhoneForm.new(
        previous_params: {},
        user: current_user,
        delivery_methods: [:sms],
      )
    end

    def render_404_if_hybrid_handoff_controller_disabled
      render_not_found unless IdentityConfig.store.doc_auth_hybrid_handoff_controller_enabled
    end

    def confirm_agreement_step_complete
      return if flow_session['Idv::Steps::AgreementStep']

      redirect_to idv_doc_auth_url
    end

    def analytics_arguments
      {
        step: 'upload',
        analytics_id: 'Doc Auth',
        irs_reproofing: irs_reproofing?,
      }.merge(**acuant_sdk_ab_test_analytics_args)
    end
  end
end
