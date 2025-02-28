# frozen_string_literal: true

module DocAuth
  module Mock
    class Socure
      def initialize
        @fixtures =
          Dir["#{Rails.root.join('spec', 'fixtures', 'socure_docv')}/*.json"].map do |fixture_file|
            Test::MockSocureConfig.new(
              name: File.basename(fixture_file),
              body: File.read(fixture_file),
            )
          end
      end

      attr_accessor :fixtures, :selected_fixture_body, :docv_transaction_token
      attr_reader :selected_fixture

      def selected_fixture=(new_value)
        if @fixtures.map(&:name).include?(new_value)
          @selected_fixture = new_value
        end
        update_fixture_body(@selected_fixture)
      end

      def update_fixture_body(new_fixture_name)
        @selected_fixture_body = nil

        body = @fixtures.find do |fixture|
          fixture.name == new_fixture_name
        end&.body

        @selected_fixture_body = JSON.parse(body, symbolize_names: true) if body
      end

      def enabled
        IdentityConfig.store.doc_auth_vendor == 'mock_socure'
      end

      def hit_webhook(endpoint:, event_type:)
        Faraday.post endpoint do |req|
          req.body = {
            event: {
              eventType: event_type,
              docvTransactionToken: docv_transaction_token,
            },
          }.to_json
          req.headers = {
            'Content-Type': 'application/json',
            Authorization: IdentityConfig.store.socure_docv_webhook_secret_key,
          }
          req.options.context = { service_name: 'socure-docv-webhook' }
        end
      end

      def hit_webhooks(endpoint:)
        %w[
          WAITING_FOR_USER_TO_REDIRECT
          APP_OPENED
          DOCUMENT_FRONT_UPLOADED
          DOCUMENT_BACK_UPLOADED
          DOCUMENTS_UPLOADED
          SESSION_COMPLETE
        ].each do |event_type|
          hit_webhook(endpoint:, event_type:)
        end
      end

    end
  end
end
