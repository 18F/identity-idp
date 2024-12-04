# frozen_string_literal: true

module Idv
  module HybridMobile
    module Socure
      class DocumentCaptureErrorsController < ApplicationController
        include Idv::AvailabilityConcern
        include IdvStepConcern
        include DocumentCaptureConcern
        include RenderConditionConcern
        include SocureErrorsConcern

        check_or_render_not_found -> { IdentityConfig.store.socure_docv_enabled }
        before_action :confirm_not_rate_limited

        # ToDo: Remove. For reference only.
        # module Idv
        #   module SocureErrorsConcern
        #     def errors
        #       @presenter = socure_errors_presenter(handle_stored_result)
        #     end

        #     def goto_in_person
        #       InPersonEnrollment.find_or_initialize_by(
        #         user: document_capture_session.user,
        #         status: :establishing,
        #         sponsor_id: IdentityConfig.store.usps_ipp_sponsor_id,
        #       ).save!

        #       redirect_to idv_in_person_url
        #     end

        #     private

        #     def remaining_attempts
        #       RateLimiter.new(
        #         user: document_capture_session.user,
        #         rate_limit_type: :idv_doc_auth,
        #       ).remaining_count
        #     end

        #     def error_code_for(result)
        #       if result.errors[:socure]
        #         result.errors.dig(:socure, :reason_codes).first
        #       elsif result.errors[:network]
        #         :network
        #       else
        #         # No error information available (shouldn't happen). Default
        #         # to :network if it does.
        #         :network
        #       end
        #     end
        #   end
        # end

        def show
          Rails.logger.info "\nshow: got here\n"

          @presenter = SocureErrorPresenter.new(
            error_code: error_code_for(handle_stored_result),
            remaining_attempts:,
            sp_name: decorated_sp_session&.sp_name || APP_NAME,
            hybrid_mobile: false,
          )
        end

        def update
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
