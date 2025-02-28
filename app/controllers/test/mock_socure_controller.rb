# frozen_string_literal: true

module Test
  class MockSocureController < ApplicationController
    layout 'no_card'

    skip_before_action :verify_authenticity_token # TODO: can we not skip this?
    before_action :check_enabled, only: [:document_request, :docv_results]

    def initialize
      @socure_provider = DocAuth::Mock::Socure.new
    end

    def index; end

    def update
      @socure_provider.selected_fixture = params[:selected_fixture]
      render :index
    end

    def document_capture
      @continue_path = test_mock_socure_document_capture_url
    end

    def document_capture_update
      @socure_provider.hit_webhooks(
        endpoint: api_webhooks_socure_event_url,
      )
      redirect_to idv_socure_document_capture_update_url
    end

    def check_enabled
      return if @socure_provider.enabled

      raise ActionController::RoutingError, 'Test Socure is disabled'
    end

    # Fake Socure endpoints
    def document_request
      @socure_provider.docv_transaction_token = SecureRandom.uuid
      render json:
             {
               data: {
                 url: test_mock_socure_document_capture_url,
                 docvTransactionToken: @socure_provider.docv_transaction_token,
               },
             }
    end

    def docv_results
      render json: @socure_provider.selected_fixture_body
    end
  end
end
