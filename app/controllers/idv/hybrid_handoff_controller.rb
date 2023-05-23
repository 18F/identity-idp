module Idv
  class HybridHandoffController < ApplicationController
    include IdvSession
    include IdvStepConcern
    include StepIndicatorConcern
    include StepUtilitiesConcern

    before_action :confirm_two_factor_authenticated
    before_action :render_404_if_hybrid_handoff_controller_disabled

    def show
      binding.pry
      analytics.idv_doc_auth_upload_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'upload', :view,
        true
      )

      render :show
    end

    def form_submit
      FormResponse.new(success: true)
    end

    def render_404_if_hybrid_handoff_controller_disabled
      binding.pry
      render_not_found unless IdentityConfig.store.doc_auth_hybrid_handoff_controller_enabled
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
