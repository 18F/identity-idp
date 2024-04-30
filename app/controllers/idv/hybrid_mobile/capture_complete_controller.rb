# frozen_string_literal: true

module Idv
  module HybridMobile
    class CaptureCompleteController < ApplicationController
      include Idv::AvailabilityConcern
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
        liveness_checking_required =
          FeatureManagement.idv_allow_selfie_check? &&
          resolved_authn_context_result.biometric_comparison?

        {
          flow_path: 'hybrid',
          step: 'capture_complete',
          analytics_id: 'Doc Auth',
          irs_reproofing: irs_reproofing?,
          liveness_checking_required:,
        }.merge(ab_test_analytics_buckets)
      end
    end
  end
end
