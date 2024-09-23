# frozen_string_literal: true

module Idv
  module HybridMobile
    module Socure
      class DocumentCaptureController < ApplicationController
        include Idv::AvailabilityConcern
        include DocumentCaptureConcern
        include Idv::HybridMobile::HybridMobileConcern

        before_action :check_valid_document_capture_session
        before_action :secure_headers_override

        def show
          Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
            call('hybrid_mobile_socure_document_capture', :view, true)

          # document request
          document_request = DocAuth::Socure::Requests::DocumentRequest.new(
            document_capture_session_uuid: document_capture_session_uuid,
            redirect_url: idv_hybrid_mobile_socure_document_capture_url,
            language: locale,
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
          # fetch result probably not needed local dev
          if (socure_document_uuid = request.params[:document_uuid])
            uploaded_documents_decision(socure_document_uuid)
          end

          # Not used in standard flow, here for data consistency with hybrid flow.
          document_capture_session.confirm_ocr
          result = handle_stored_result

          Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
            call('document_capture', :update, true)

          cancel_establishing_in_person_enrollments

          if result.success?
            flash[:success] = t('doc_auth.headings.capture_complete')
            redirect_to idv_hybrid_mobile_capture_complete_url
          else
            redirect_to idv_hybrid_mobile_socure_document_capture_url
          end
        end

        private

        def cancel_establishing_in_person_enrollments
          UspsInPersonProofing::EnrollmentHelper.
            cancel_stale_establishing_enrollments_for_user(document_capture_user)
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

        def secure_headers_override
          override_form_action_csp(
            SecureHeadersAllowList.csp_with_sp_redirect_uris(
              idv_hybrid_mobile_socure_document_capture_url,
              ['https://verify.socure.us'],
            ),
          )
        end
      end
    end
  end
end
