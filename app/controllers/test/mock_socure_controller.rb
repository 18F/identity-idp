# frozen_string_literal: true

module Test
  class MockSocureController < ApplicationController
    layout 'no_card'

    skip_before_action :verify_authenticity_token # TODO: can we not skip this?
    before_action :check_enabled

    # Fake Socure UI
    def index
    end

    def update
      DocAuth::Mock::Socure.instance.selected_fixture = params[:selected_fixture]
      render :index
    end

    def continue
      DocAuth::Mock::Socure.instance.selected_fixture = params[:selected_fixture]
      DocAuth::Mock::Socure.instance.hit_webhooks

      redirect_to idv_socure_document_capture_update_url
    end

    def check_enabled
      return if DocAuth::Mock::Socure.instance.enabled

      raise ActionController::RoutingError, 'Test Socure is disabled'
    end

    # Fake Socure endpoints
    def document_request
      DocAuth::Mock::Socure.instance.docv_transaction_token = SecureRandom.uuid
      return_body = {
        data: {
          url: test_mock_socure_document_capture_url,
          docvTransactionToken: DocAuth::Mock::Socure.instance.docv_transaction_token,
        },
      }

      Rails.logger.info "\n\ndocument_request: return_body: #{return_body.inspect}\n"

      render json: return_body
    end

    def docv_results
      render json: DocAuth::Mock::Socure.instance.selected_fixture_body
    end
  end
end
