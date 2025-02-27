# frozen_string_literal: true

module Test
  class MockSocureController < ApplicationController
    skip_before_action :verify_authenticity_token # TODO: can we not skip this?
    before_action :check_enabled

    def document_request
      DocAuth::Mock::Socure.docv_transaction_token = SecureRandom.uuid
      render json:
             {
               data: {
                 url: test_mock_socure_ui_document_capture_url,
                 docvTransactionToken: DocAuth::Mock::Socure.docv_transaction_token,
               },
             }
    end

    def docv_results
      render json: DocAuth::Mock::Socure.selected_fixture_body
    end

    def check_enabled
      return if DocAuth::Mock::Socure.enabled

      raise ActionController::RoutingError, 'Test Socure is disabled'
    end
  end
end
