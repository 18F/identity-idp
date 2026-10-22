# frozen_string_literal: true

module Test
  class MockSocureController < ApplicationController
    layout 'no_card'

    skip_before_action :verify_authenticity_token # TODO: can we not skip this?
    before_action :check_enabled

    # Fake Socure UI
    def index; end

    def update
      update_from_params
      render :index
    end

    def continue
      update_from_params
      DocAuth::Mock::Socure.instance.hit_webhooks

      redirect_to idv_socure_document_capture_update_url
    end

    def check_enabled
      return if DocAuth::Mock::Socure.instance.enabled?

      raise ActionController::RoutingError, 'Test Socure is disabled'
    end

    # Fake Socure endpoints
    def document_request
      DocAuth::Mock::Socure.instance.start_capture_session
      return_body = {
        data: {
          url: test_mock_socure_document_capture_url,
          docvTransactionToken: DocAuth::Mock::Socure.instance.docv_transaction_token,
        },
      }

      render json: return_body
    end

    def docv_results
      render json: DocAuth::Mock::Socure.instance.selected_fixture_body
    end

    # Local Socure simulator only: use the same ZIP format as the vendor API.
    def images_request
      require Rails.root.join('spec/support/doc_auth_image_fixtures')
      selected = DocAuth::Mock::Socure.instance.selected_fixture.to_s
      send_data(
        DocAuthImageFixtures.zipped_files(
          reference_id: 'local-socure',
          passport: selected == 'passport_pass.json',
          selfie: false,
        ),
        filename: 'document.zip',
        type: 'application/zip',
      )
    end

    private

    def update_from_params
      if params['fixture']['selected_fixture'] != DocAuth::Mock::Socure.instance.selected_fixture
        DocAuth::Mock::Socure.instance.selected_fixture = params['fixture']['selected_fixture']
      elsif DocAuth::Mock::Socure.instance.selected_fixture_body
        DocAuth::Mock::Socure.instance.decision = params['fixture']['decision']
        DocAuth::Mock::Socure.instance.reason_codes =
          params['fixture']['reason_codes']&.compact_blank
      end
    end
  end
end
