module Idv
  module HybridMobile
    class CaptureCompleteController < ApplicationController
      include IdvSession
      include IdvStepConcern
      include StepIndicatorConcern
      include StepUtilitiesConcern

      before_action :render_404_if_hybrid_mobile_controllers_disabled

      def show
        increment_step_counts

        analytics.idv_doc_auth_capture_complete_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('capture_complete', :view, true)

        render :show
      end

      private

      def render_404_if_hybrid_mobile_controllers_disabled
        render_not_found unless IdentityConfig.store.doc_auth_hybrid_mobile_controllers_enabled
      end

      def analytics_arguments
        {
          flow_path: 'hybrid',
          step: 'capture_complete',
          step_count: current_flow_step_counts['Idv::Steps::CaptureCompleteStep'],
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
        current_flow_step_counts['Idv::Steps::CaptureCompleteStep'] += 1
      end
    end
  end
end
