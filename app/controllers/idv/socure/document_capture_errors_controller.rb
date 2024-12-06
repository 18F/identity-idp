# frozen_string_literal: true

module Idv
  module Socure
    class DocumentCaptureErrorsController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern
      include DocumentCaptureConcern
      include RenderConditionConcern
      include SocureErrorsConcern

      check_or_render_not_found -> { IdentityConfig.store.socure_docv_enabled }
      before_action :confirm_not_rate_limited

      def show
        @presenter = SocureErrorPresenter.new(
          error_code: error_code_for(handle_stored_result),
          remaining_attempts:,
          sp_name: decorated_sp_session&.sp_name || APP_NAME,
          hybrid_mobile: false,
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
    end
  end
end
