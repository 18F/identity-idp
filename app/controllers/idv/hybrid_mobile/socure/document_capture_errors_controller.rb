# frozen_string_literal: true

module Idv
  module HybridMobile
    module Socure
      class DocumentCaptureErrorsController < ApplicationController
        include Idv::AvailabilityConcern
        include DocumentCaptureConcern
        include Idv::HybridMobile::HybridMobileConcern
        include RenderConditionConcern
        include SocureErrorsConcern

        check_or_render_not_found -> { IdentityConfig.store.socure_docv_enabled }

        def show
          @presenter = SocureErrorPresenter.new(
            error_code: error_code_for(handle_stored_result),
            remaining_attempts:,
            sp_name: decorated_sp_session&.sp_name || APP_NAME,
            hybrid_mobile: true,
          )
        end

        # ToDo: Remove and use Doug's method
        def goto_in_person
          enrollment = InPersonEnrollment.find_or_initialize_by(
            user: document_capture_session.user,
            status: :establishing,
            sponsor_id: IdentityConfig.store.usps_ipp_sponsor_id,
          )
          enrollment.save!

          redirect_to idv_in_person_url
        end

        # def analytics_arguments
        #   {
        #     flow_path: flow_path,
        #     step: 'socure_document_capture',
        #     analytics_id: 'Doc Auth',
        #     redo_document_capture: idv_session.redo_document_capture,
        #     skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
        #     liveness_checking_required: resolved_authn_context_result.facial_match?,
        #     selfie_check_required: resolved_authn_context_result.facial_match?,
        #   }.merge(ab_test_analytics_buckets)
        # end
      end
    end
  end
end
