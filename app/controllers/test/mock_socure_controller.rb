# frozen_string_literal: true

module Test
  class MockSocureController < ApplicationController
    layout 'no_card'

    skip_before_action :verify_authenticity_token # TODO: can we not skip this?
    before_action :check_enabled, only: [:document_request, :docv_results]

    def index
      # TODO: pass these in a more civilized fashion.
      @socure_fixtures = DocAuth::Mock::Socure.fixtures
      @selected_fixture = DocAuth::Mock::Socure.selected_fixture
      @selected_fixture_body = DocAuth::Mock::Socure.selected_fixture_body
      @enabled = DocAuth::Mock::Socure.enabled
    end

    def update
      DocAuth::Mock::Socure.selected_fixture = params[:selected_fixture]
      DocAuth::Mock::Socure.enabled = params[:enabled] == '1'

      @socure_fixtures = DocAuth::Mock::Socure.fixtures
      @selected_fixture = DocAuth::Mock::Socure.selected_fixture
      @selected_fixture_body = DocAuth::Mock::Socure.selected_fixture_body
      @enabled = DocAuth::Mock::Socure.enabled

      render :index
    end

    def document_capture
      @continue_path = test_mock_socure_document_capture_url
    end

    def document_capture_update
      DocAuth::Mock::Socure.hit_webhooks(
        endpoint: api_webhooks_socure_event_url,
      )
      redirect_to idv_socure_document_capture_update_url
    end

    def check_enabled
      return if DocAuth::Mock::Socure.enabled

      raise ActionController::RoutingError, 'Test Socure is disabled'
    end

    # Fake Socure endpoints
    def document_request
      DocAuth::Mock::Socure.docv_transaction_token = SecureRandom.uuid
      render json:
             {
               data: {
                 url: test_mock_socure_document_capture_url,
                 docvTransactionToken: DocAuth::Mock::Socure.docv_transaction_token,
               },
             }
    end

    def docv_results
      render json: DocAuth::Mock::Socure.selected_fixture_body
    end
  end
end
