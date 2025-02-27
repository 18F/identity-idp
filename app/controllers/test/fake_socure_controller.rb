# frozen_string_literal: true

module Test
  class FakeSocureController < ApplicationController
    skip_before_action :verify_authenticity_token # TODO: can we not skip this?
    before_action :check_enabled

    def document_request
      MockSocure.docv_transaction_token = SecureRandom.uuid
      render json:
             {
               data: {
                 url: test_fake_socure_ui_document_capture_url,
                 docvTransactionToken: MockSocure.docv_transaction_token,
               },
             }
    end

    def docv_results
      render json: MockSocure.selected_fixture_body
    end

    def check_enabled
      return if MockSocure.enabled

      raise ActionController::RoutingError, 'Test Socure is disabled'
    end
  end
end
