# frozen_string_literal: true

module Idv
  module HybridMobile
    class ChooseIdTypeController < ApplicationController
      include Idv::AvailabilityConcern
      include HybridMobileConcern
      include DocumentCaptureConcern
      include Idv::ChooseIdTypeConcern
      include ThreatMetrixHelper
      include ThreatMetrixConcern

      before_action :check_valid_document_capture_session
      before_action :override_csp_for_threat_metrix,
                    if: -> {
                      FeatureManagement.proofing_device_hybrid_profiling_collecting_enabled?
                    }

      def show
        analytics.idv_doc_auth_choose_id_type_visited(**analytics_arguments)

        render 'idv/shared/choose_id_type', locals: choose_id_type_attrs
      end

      def update
        @choose_id_type_form = Idv::ChooseIdTypeForm.new

        result = @choose_id_type_form.submit(choose_id_type_form_params)

        analytics.idv_doc_auth_choose_id_type_submitted(
          **analytics_arguments.merge(result.to_h)
              .merge({ chosen_id_type: }),
        )

        if FeatureManagement.proofing_device_hybrid_profiling_collecting_enabled? &&
           in_hybrid_tmx_ab_test_bucket?
          add_hybrid_threatmetrix_variables_to_document_capture_session
        end

        if passport_chosen? &&
           !dos_passport_api_healthy?(analytics:, step: 'choose_id_type')
          redirect_to idv_hybrid_mobile_choose_id_type_url(passports: false)
        elsif result.success?
          set_passport_requested
          redirect_to next_step
        else
          redirect_to idv_hybrid_mobile_choose_id_type_url
        end
      end

      private

      def in_hybrid_tmx_ab_test_bucket?
        ab_test_bucket(:HYBRID_MOBILE_TMX_PROCESSED) == :hybrid_mobile_tmx_processed
      end

      def add_hybrid_threatmetrix_variables_to_document_capture_session
        document_capture_session.hybrid_mobile_threatmetrix_session_id =
          session[:hybrid_flow_threatmetrix_session_id]
        document_capture_session.hybrid_mobile_request_ip = request&.remote_ip
        document_capture_session.save
      end

      def next_step
        idv_hybrid_mobile_document_capture_url
      end

      def choose_id_type_attrs
        locals_attrs(
          presenter: Idv::HybridMobile::ChooseIdTypePresenter.new,
          form_submit_url: idv_hybrid_mobile_choose_id_type_path,
        ).merge!(threatmetrix_variables(hybrid_flow: true))
      end

      def analytics_arguments
        {
          step: 'hybrid_choose_id_type',
          analytics_id: 'Doc Auth',
          flow_path: 'hybrid',
        }
      end
    end
  end
end
