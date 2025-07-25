# frozen_string_literal: true

module Idv
  class AgreementController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern
    include StepIndicatorConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_step_allowed

    def show
      analytics.idv_doc_auth_agreement_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).call(
        'agreement', :view,
        true
      )

      @consent_form = Idv::ConsentForm.new(
        idv_consent_given: idv_session.idv_consent_given?,
      )
    end

    def update
      clear_future_steps!
      skip_to_capture if params[:skip_hybrid_handoff]

      @consent_form = Idv::ConsentForm.new(
        idv_consent_given: idv_session.idv_consent_given?,
      )
      result = @consent_form.submit(consent_form_params)

      analytics.idv_doc_auth_agreement_submitted(
        **analytics_arguments.merge(result.to_h),
      )

      if current_user.has_proofed_before?
        attempts_api_tracker.idv_reproof
      end

      if result.success?
        idv_session.idv_consent_given_at = Time.zone.now

        if params[:skip_hybrid_handoff]
          if in_person_proofing_route_enabled?
            redirect_to idv_how_to_verify_url
          elsif idv_session.passport_allowed
            idv_session.opted_in_to_in_person_proofing = false
            idv_session.skip_doc_auth_from_how_to_verify = false
            redirect_to idv_choose_id_type_url
          else
            redirect_to idv_how_to_verify_url
          end
        else
          idv_session.opted_in_to_in_person_proofing = false
          idv_session.skip_doc_auth_from_how_to_verify = false
          redirect_to idv_hybrid_handoff_url
        end
      else
        render :show
      end
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :agreement,
        controller: self,
        next_steps: [:hybrid_handoff, :choose_id_type, :document_capture, :how_to_verify],
        preconditions: ->(idv_session:, user:) { idv_session.welcome_visited },
        undo_step: ->(idv_session:, user:) do
          idv_session.idv_consent_given_at = nil
          idv_session.skip_hybrid_handoff = nil
        end,
      )
    end

    private

    def analytics_arguments
      {
        step: 'agreement',
        analytics_id: 'Doc Auth',
        skip_hybrid_handoff: idv_session.skip_hybrid_handoff,
      }.merge(ab_test_analytics_buckets)
    end

    def in_person_proofing_route_enabled?
      IdentityConfig.store.in_person_proofing_enabled &&
        IdentityConfig.store.in_person_proofing_opt_in_enabled
    end

    def skip_to_capture
      idv_session.flow_path = 'standard'

      # Store that we're skipping hybrid handoff so if the user
      # tries to redo document capture they can skip it then too.
      idv_session.skip_hybrid_handoff = true
    end

    def consent_form_params
      params.require(:doc_auth).permit(:idv_consent_given)
    end
  end
end
