# frozen_string_literal: true

module Test
  class FakeSocureUiController < ApplicationController
    layout 'no_card'

    # TODO: can we not skip this?
    skip_before_action :verify_authenticity_token

    def index
      # TODO: pass these in a more civilized fashion.
      @socure_fixtures = FakeSocureController.fixtures
      @selected_fixture = FakeSocureController.selected_fixture
      @selected_fixture_body = FakeSocureController.selected_fixture_body
      @enabled = FakeSocureController.enabled
    end

    def update
      FakeSocureController.selected_fixture = params[:selected_fixture]
      FakeSocureController.enabled = params[:enabled] == '1'

      @socure_fixtures = FakeSocureController.fixtures
      @selected_fixture = FakeSocureController.selected_fixture
      @selected_fixture_body = FakeSocureController.selected_fixture_body
      @enabled = FakeSocureController.enabled

      render :index
    end

    def document_capture
      @continue_path = test_fake_socure_ui_document_capture_url
    end

    def document_capture_update
      FakeSocureController.hit_webhooks(
        docv_transaction_token: 'docv_transaction_token',
        endpoint: api_webhooks_socure_event_url,
      )
      redirect_to idv_socure_document_capture_update_url
    end
  end
end
