# frozen_string_literal: true

module Test
  class MockSocureUiController < ApplicationController
    layout 'no_card'

    # TODO: can we not skip this?
    skip_before_action :verify_authenticity_token

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
      @continue_path = test_mock_socure_ui_document_capture_url
    end

    def document_capture_update
      DocAuth::Mock::Socure.hit_webhooks(
        endpoint: api_webhooks_socure_event_url,
      )
      redirect_to idv_socure_document_capture_update_url
    end
  end
end
