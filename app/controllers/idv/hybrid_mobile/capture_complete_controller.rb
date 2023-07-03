module Idv
  module HybridMobile
    class CaptureCompleteController < ApplicationController
      include HybridMobileConcern

      before_action :check_valid_document_capture_session

      def show
        analytics.idv_doc_auth_capture_complete_visited(**analytics_arguments)

        Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
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
