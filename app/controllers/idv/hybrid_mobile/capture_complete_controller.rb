module Idv
  module HybridMobile
    class CaptureCompleteController < ApplicationController
      include IdvSession
      include IdvStepConcern
      include StepIndicatorConcern
      include StepUtilitiesConcern
      include HybridMobileConcern

      def show
        analytics.idv_doc_auth_capture_complete_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('capture_complete', :view, true)

        render :show
      end

      private

      def analytics_arguments
        {
          flow_path: 'hybrid',
          step: 'capture_complete',
          analytics_id: 'Doc Auth',
          irs_reproofing: irs_reproofing?,
        }.merge(**acuant_sdk_ab_test_analytics_args)
      end
    end
  end
end
