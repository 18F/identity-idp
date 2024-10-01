# frozen_string_literal: true

module Idv
  module HybridMobile
    module Socure
      class DocumentCaptureController < ApplicationController
        include Idv::AvailabilityConcern
        include DocumentCaptureConcern
        include Idv::HybridMobile::HybridMobileConcern

        before_action :check_valid_document_capture_session

        def show
          Funnel::DocAuth::RegisterStep.new(document_capture_user.id, sp_session[:issuer]).
            call('hybrid_mobile_socure_document_capture', :view, true)

          # document request
          document_request = DocAuth::Socure::Requests::DocumentRequest.new(
            document_capture_session_uuid: document_capture_session_uuid,
            redirect_url: idv_hybrid_mobile_socure_document_capture_url,
            language: I18n.locale,
          )
          document_response = document_request.fetch

          @document_request = document_request
          @document_response = document_response
          @url = document_response.dig('data', 'url')

          document_capture_session = DocumentCaptureSession.find_by(
            uuid: document_capture_session_uuid,
          )
          document_capture_session.socure_docv_token = document_response.dig(
            'data',
            'docvTransactionToken',
          )
          document_capture_session.save

          # useful for analytics
          @msg = document_response['msg']
          @reference_id = document_response.dig('referenceId')
        end
      end
    end
  end
end
