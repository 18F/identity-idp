# frozen_string_literal: true

module Idv
  class SocureDocumentCaptureController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern

    before_action :confirm_not_rate_limited
    before_action :confirm_step_allowed

    def show
      Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
        call('document_capture', :view, true)

      # document request
      document_request = DocAuth::Socure::Requests::DocumentRequest.new(
        document_capture_session_uuid: document_capture_session_uuid,
        redirect_url: idv_document_capture_socure_redirect_url, # might be update action
        verificaiton_level: request.params['verification_level'],
        language: locale,
      )

      document_response = document_request.fetch

      @url = document_response.dig('data', 'url')
      @msg = document_response['msg']
      @reference_id = document_response.dig('referenceId')
      @qr_code = nil

      redirect_to @url, allow_other_host: true if @url.present?
    end

    def update
      clear_future_steps!
      idv_session.redo_document_capture = nil # done with this redo

      # fetch result
      if (socure_document_uuid = request.params[:document_uuid])
        uploaded_documents_decision(socure_document_uuid)
      end

      # Not used in standard flow, here for data consistency with hybrid flow.
      document_capture_session.confirm_ocr
      result = handle_stored_result

      analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

      Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
        call('document_capture', :update, true)

      cancel_establishing_in_person_enrollments

      if result.success?
        redirect_to idv_ssn_url
      else
        redirect_to idv_socure_document_capture_url
      end
    end
  end

  private

  def cancel_establishing_in_person_enrollments
    UspsInPersonProofing::EnrollmentHelper.
      cancel_stale_establishing_enrollments_for_user(current_user)
  end

  def handle_stored_result
    if stored_result&.success? && selfie_requirement_met?
      save_proofing_components(current_user)
      extract_pii_from_doc(current_user, store_in_session: true)
      flash[:success] = t('doc_auth.headings.capture_complete')
      successful_response
    else
      extra = { stored_result_present: stored_result.present? }
      failure(I18n.t('doc_auth.errors.general.network_error'), extra)
    end
  end
end
