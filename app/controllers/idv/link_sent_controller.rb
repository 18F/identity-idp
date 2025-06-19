# frozen_string_literal: true

module Idv
  class LinkSentController < ApplicationController
    include Idv::AvailabilityConcern
    include DocumentCaptureConcern
    include IdvStepConcern
    include StepIndicatorConcern

    before_action -> do
      confirm_not_rate_limited(check_last_submission: true)
    end

    before_action :confirm_step_allowed

    def show
      analytics.idv_doc_auth_link_sent_visited(**analytics_arguments)

      Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer])
        .call('link_sent', :view, true)

      render :show, locals: extra_view_variables
    end

    def update
      clear_future_steps!
      analytics.idv_doc_auth_link_sent_submitted(**analytics_arguments)

      return render_document_capture_cancelled if document_capture_session&.cancelled_at

      # If the user opted into in-person proofing in the hybrid session,
      # we should be able to find an establishing IPP enrollment
      if current_user.has_establishing_in_person_enrollment?
        redirect_to idv_in_person_url
        return
      end

      # Otherwise, we assume the user is still in the remote doc auth flow.

      return render_step_incomplete_error unless take_photo_with_phone_successful?

      # The doc capture flow will have fetched the results already. We need
      # to fetch them again here to add the PII to this session
      handle_document_verification_success
      idv_session.redo_document_capture = nil

      redirect_to idv_ssn_url
    end

    def extra_view_variables
      { phone: idv_session.phone_for_mobile_flow }
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :link_sent,
        controller: self,
        next_steps: [:ssn],
        preconditions: ->(idv_session:, user:) { idv_session.flow_path == 'hybrid' },
        undo_step: ->(idv_session:, user:) do
          idv_session.pii_from_doc = nil
          idv_session.invalidate_in_person_pii_from_user!
          idv_session.had_barcode_attention_error = nil
          idv_session.had_barcode_read_failure = nil
          idv_session.selfie_check_performed = nil
          idv_session.reset_doc_auth_vendor!
        end,
      )
    end

    private

    def analytics_arguments
      {
        step: 'link_sent',
        analytics_id: 'Doc Auth',
        flow_path: 'hybrid',
      }.merge(ab_test_analytics_buckets)
    end

    def handle_document_verification_success
      extract_pii_from_doc(current_user, store_in_session: true)
      idv_session.flow_path = 'hybrid'
    end

    def render_document_capture_cancelled
      redirect_to idv_hybrid_handoff_url
      idv_session.flow_path = nil
      failure(I18n.t('doc_auth.errors.document_capture_canceled'))
    end

    def render_step_incomplete_error
      failure(I18n.t('doc_auth.errors.phone_step_incomplete'))
    end

    def take_photo_with_phone_successful?
      stored_result&.success? && selfie_requirement_met?
    end
  end
end
