module Idv
  class HowToVerifyController < ApplicationController
    include RenderConditionConcern

    check_or_render_not_found -> { enabled? }

    def show
      @idv_how_to_verify_form = Idv::HowToVerifyForm.new
    end

    def update
      if how_to_verify_form_params['selection'] == 'ipp'
        redirect_to idv_document_capture_url
      else
        redirect_to idv_hybrid_handoff_url
      end
    end

    private

    def how_to_verify_form_params
      params.require(:idv_how_to_verify_form).permit(:selection)
    end

    def enabled?
      IdentityConfig.store.in_person_proofing_opt_in_option
    end
  end
end
