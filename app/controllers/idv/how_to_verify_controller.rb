module Idv
  class HowToVerifyController < ApplicationController
    include RenderConditionConcern

    check_or_render_not_found -> { enabled? }

    VERIFICATION_OPTIONS = %w[ipp remote].freeze

    def show
      analytics.idv_doc_auth_how_to_verify_visited(**analytics_arguments)
      @idv_how_to_verify_form = Idv::HowToVerifyForm.new
      @verification_options = VERIFICATION_OPTIONS
    end

    def update
      analytics.idv_doc_auth_how_to_verify_submitted(**analytics_arguments)
      if how_to_verify_form_params['selection'] == VERIFICATION_OPTIONS[:ipp]
        redirect_to idv_document_capture_url
      else
        redirect_to idv_hybrid_handoff_url
      end
    end

    private

    def analytics_arguments
      {
        step: 'how_to_verify',
        analytics_id: 'Doc Auth',
      }
    end

    def how_to_verify_form_params
      params.require(:idv_how_to_verify_form).permit(:selection)
    end

    def enabled?
      IdentityConfig.store.in_person_proofing_opt_in_option
    end
  end
end
