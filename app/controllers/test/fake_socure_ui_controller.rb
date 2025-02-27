# frozen_string_literal: true

module Test
  class FakeSocureUiController < ApplicationController
    layout 'no_card'

    # TODO: can we not skip this?
    skip_before_action :verify_authenticity_token

    def index
      # TODO: pass these in a more civilized fashion.
      @socure_fixtures = MockSocure.fixtures
      @selected_fixture = MockSocure.selected_fixture
      @selected_fixture_body = MockSocure.selected_fixture_body
      @enabled = MockSocure.enabled
    end

    def update
      MockSocure.selected_fixture = params[:selected_fixture]
      MockSocure.enabled = params[:enabled] == '1'

      @socure_fixtures = MockSocure.fixtures
      @selected_fixture = MockSocure.selected_fixture
      @selected_fixture_body = MockSocure.selected_fixture_body
      @enabled = MockSocure.enabled

      render :index
    end

    def document_capture
      @continue_path = test_fake_socure_ui_document_capture_url
    end

    def document_capture_update
      MockSocure.hit_webhooks(
        endpoint: api_webhooks_socure_event_url,
      )
      redirect_to idv_socure_document_capture_update_url
    end
  end
end
