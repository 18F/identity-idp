# frozen_string_literal: true

module Idv
  module Socure
    class DocumentCaptureController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvStepConcern

      before_action :confirm_not_rate_limited
      before_action :confirm_step_allowed

      def show
        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('socure_document_capture', :view, true)

        # document request
        document_request = DocAuth::Socure::Requests::DocumentRequest.new(
          document_capture_session_uuid: document_capture_session_uuid,
          redirect_url: idv_socure_document_capture_url,
          language: :en,
        )

        document_response = document_request.fetch

        @document_request = document_request
        @document_response = document_response
        @url = document_response.dig('data', 'url')

        # useful for analytics
        @msg = document_response['msg']
        @reference_id = document_response.dig('referenceId')

        redirect_to @url, allow_other_host: true if @url.present?
      end

      def update
        clear_future_steps!
        idv_session.redo_document_capture = nil # done with this redo

        # fetch result probably not needed local dev
        if (socure_document_uuid = request.params[:document_uuid])
          uploaded_documents_decision(socure_document_uuid)
        end

        # Not used in standard flow, here for data consistency with hybrid flow.
        document_capture_session.confirm_ocr
        result = handle_stored_result

        analytics.idv_doc_auth_document_capture_submitted(**result.to_h.merge(analytics_arguments))

        Funnel::DocAuth::RegisterStep.new(current_user.id, sp_session[:issuer]).
          call('document_capture', :update, true)

        cancel_establishing_in_person_enrollments

        if result.success?
          redirect_to idv_ssn_url
        else
          redirect_to idv_socure_document_capture_url
        end
      end

      def self.step_info
        Idv::StepInfo.new(
          key: :socure_document_capture,
          controller: self,
          next_steps: [:ssn, :ipp_ssn],
          preconditions: ->(idv_session:, user:) {
                           idv_session.flow_path == 'standard' && (
                            # mobile
                            idv_session.skip_doc_auth_from_handoff ||
                            idv_session.skip_hybrid_handoff ||
                              idv_session.skip_doc_auth ||
                              idv_session.skip_doc_auth_from_how_to_verify ||
                              !idv_session.selfie_check_required ||
                              idv_session.desktop_selfie_test_mode_enabled?
                          )
                         },
          undo_step: ->(idv_session:, user:) do
            idv_session.pii_from_doc = nil
            idv_session.invalidate_in_person_pii_from_user!
          end,
        )
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
  end
end
