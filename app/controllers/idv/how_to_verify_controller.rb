module Idv
  class HowToVerifyController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include RenderConditionConcern

    before_action :confirm_step_allowed

    check_or_render_not_found -> { self.class.enabled? }

    def show
      analytics.idv_doc_auth_how_to_verify_visited(**analytics_arguments)
      @idv_how_to_verify_form = Idv::HowToVerifyForm.new
    end

    def update
      clear_future_steps!
      result = Idv::HowToVerifyForm.new.submit(how_to_verify_form_params)

      analytics.idv_doc_auth_how_to_verify_submitted(
        **analytics_arguments.merge(result.to_h),
      )

      if result.success?
        if how_to_verify_form_params['selection'] == Idv::HowToVerifyForm::REMOTE
          idv_session.opted_in_to_in_person_proofing = false
          redirect_to idv_hybrid_handoff_url
        else
          idv_session.opted_in_to_in_person_proofing = true
          redirect_to idv_document_capture_url
        end
      else
        flash[:error] = result.first_error_message
        redirect_to idv_how_to_verify_url
      end
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :how_to_verify,
        controller: controller_name,
        next_steps: [:hybrid_handoff, :document_capture],
        preconditions: ->(idv_session:, user:) do
          self.enabled? && idv_session.idv_consent_given
        end,
        undo_step: ->(idv_session:, user:) {}, # clear any saved data
      )
    end

    def self.enabled?
      IdentityConfig.store.in_person_proofing_opt_in_enabled
    end

    private

    def analytics_arguments
      {
        step: 'how_to_verify',
        analytics_id: 'Doc Auth',
      }
    end

    def how_to_verify_form_params
      params.require(:idv_how_to_verify_form).permit(:selection, selection: [])
    rescue ActionController::ParameterMissing
      ActionController::Parameters.new(selection: [])
    end
  end
end
