# frozen_string_literal: true

module Idv
  class HowToVerifyController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include RenderConditionConcern
    include DocAuthVendorConcern

    before_action :confirm_step_allowed
    before_action :set_how_to_verify_presenter

    check_or_render_not_found -> { self.class.enabled? }

    def show
      analytics.idv_doc_auth_how_to_verify_visited(**analytics_arguments)
      @idv_how_to_verify_form = Idv::HowToVerifyForm.new
    end

    def update
      clear_future_steps!
      @idv_how_to_verify_form = Idv::HowToVerifyForm.new
      result = @idv_how_to_verify_form.submit(how_to_verify_form_params)

      if how_to_verify_form_params[:selection] == []
        sendable_form_params = {}
      else
        sendable_form_params = how_to_verify_form_params.to_h.symbolize_keys
      end

      analytics.idv_doc_auth_how_to_verify_submitted(
        **analytics_arguments.merge(sendable_form_params).merge(result.to_h),
      )

      if result.success?
        if how_to_verify_form_params['selection'] == Idv::HowToVerifyForm::REMOTE
          idv_session.opted_in_to_in_person_proofing = false
          idv_session.skip_doc_auth_from_how_to_verify = false
          redirect_to idv_hybrid_handoff_url
        else
          idv_session.opted_in_to_in_person_proofing = true
          idv_session.flow_path = 'standard'
          idv_session.skip_doc_auth_from_how_to_verify = true
          redirect_to idv_document_capture_url(step: :how_to_verify)
        end
      else
        render :show, locals: { error: result.first_error_message }
      end
    end

    def self.enabled?
      IdentityConfig.store.in_person_proofing_opt_in_enabled &&
        IdentityConfig.store.in_person_proofing_enabled
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :how_to_verify,
        controller: self,
        next_steps: [:hybrid_handoff, :document_capture],
        preconditions: ->(idv_session:, user:) do
          self.enabled? &&
          idv_session.idv_consent_given? &&
          idv_session.service_provider&.in_person_proofing_enabled
        end,
        undo_step: ->(idv_session:, user:) {
                     idv_session.skip_doc_auth_from_how_to_verify = nil
                     idv_session.opted_in_to_in_person_proofing = nil
                   },
      )
    end

    private

    def analytics_arguments
      {
        step: 'how_to_verify',
        analytics_id: 'Doc Auth',
        skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
      }.merge(ab_test_analytics_buckets)
    end

    def how_to_verify_form_params
      params.require(:idv_how_to_verify_form).permit(:selection, selection: [])
    rescue ActionController::ParameterMissing
      ActionController::Parameters.new(selection: [])
    end

    def set_how_to_verify_presenter
      @mobile_required = mobile_required?
      @selfie_required = idv_session.selfie_check_required
      @presenter = Idv::HowToVerifyPresenter.new(
        mobile_required: @mobile_required,
        selfie_check_required: @selfie_required,
      )
    end

    def mobile_required?
      idv_session.selfie_check_required || doc_auth_vendor == Idp::Constants::Vendors::SOCURE
    end
  end
end
