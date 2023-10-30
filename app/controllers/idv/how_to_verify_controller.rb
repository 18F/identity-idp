module Idv
  class HowToVerifyController < ApplicationController
    include RenderConditionConcern

    REMOTE = 'remote'
    IPP = 'ipp'
    VERIFICATION_OPTIONS = [REMOTE, IPP].freeze

    check_or_render_not_found -> { enabled? }

    def show
      analytics.idv_doc_auth_how_to_verify_visited(**analytics_arguments)
      @idv_how_to_verify_form = Idv::HowToVerifyForm.new
    end

    def update
      result = Idv::HowToVerifyForm.new.submit(how_to_verify_form_params)

      analytics.idv_doc_auth_how_to_verify_submitted(
        **analytics_arguments.merge(result.to_h)
      )

      if result.success?
        if how_to_verify_form_params['selection'] == REMOTE
          redirect_to idv_document_capture_url
        else
          redirect_to idv_hybrid_handoff_url
        end
      else
        flash[:error] = result.errors[:selection].first
        redirect_to idv_how_to_verify_url
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
