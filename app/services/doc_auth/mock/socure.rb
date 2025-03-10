# frozen_string_literal: true

module DocAuth
  module Mock
    class Socure
      include Singleton

      SocureError = Struct.new(:id, :text)

      ERRORS = [
        SocureError.new('I848', 'I848'),
        SocureError.new('I854', 'I854'),
        SocureError.new('R810', 'R810'),
        SocureError.new('R820', 'R820'),
        SocureError.new('R822', 'R822'),
        SocureError.new('R823', 'R823'),
        SocureError.new('R824', 'R824'),
        SocureError.new('R825', 'R825'),
        SocureError.new('R826', 'R826'),
        SocureError.new('R831', 'R831'),
        SocureError.new('R833', 'R833'),
        SocureError.new('R838', 'R838'),
        SocureError.new('R859', 'R859'),
        SocureError.new('R861', 'R861'),
        SocureError.new('R863', 'R863'),
        SocureError.new('I849', 'I849'),
        SocureError.new('R853', 'R853'),
        SocureError.new('R827', 'R827'),
        SocureError.new('I808', 'I808'),
        SocureError.new('R845', 'R845'),
        SocureError.new('I856', 'I856'),
        SocureError.new('R819', 'R819'),
        SocureError.new('I831', 'I831'),
      ].freeze

      SocureVerdict = Struct.new(:id, :text)

      VERDICTS = [
        SocureVerdict.new('accept', 'Accept'),
        SocureVerdict.new('fail', 'Fail'),
      ].freeze

      SocureFixture = Struct.new(:name, :body) do
        def pretty_name
          name.gsub(/\W+/, ' ')
            .gsub(/\.json$/, '')
            .titlecase
        end
      end

      WEBHOOKS = %w[
        WAITING_FOR_USER_TO_REDIRECT
        APP_OPENED
        DOCUMENT_FRONT_UPLOADED
        DOCUMENT_BACK_UPLOADED
        DOCUMENTS_UPLOADED
        SESSION_COMPLETE
      ].freeze

      DATA_PATHS = {
        decision: %i[documentVerification decision value],
        reason_codes: %i[documentVerification reasonCodes],
      }.freeze

      DATA_PATHS.each do |name, path|
        define_method(name) { body_data(path) }
        define_method(:"#{name}=") { |new_value| set_body_data(path, new_value) }
      end

      attr_accessor :fixtures, :selected_fixture_body, :docv_transaction_token
      attr_reader :selected_fixture

      def selected_fixture=(new_value)
        if @fixtures.map(&:name).include?(new_value)
          @selected_fixture = new_value
        end
        update_fixture_body(@selected_fixture)
      end

      def enabled?
        IdentityConfig.store.doc_auth_vendor_default == 'mock_socure' &&
          !Rails.env.production?
      end

      def hit_webhooks
        return if !enabled?

        WEBHOOKS.each do |event_type|
          hit_webhook(event_type:)
        end
      end

      def results_endpoint
        Rails.application.routes.url_helpers.test_mock_socure_auth_score_url
      end

      def start_capture_session
        self.docv_transaction_token = SecureRandom.uuid
      end

      private

      def initialize
        @fixtures =
          Dir["#{Rails.root.join('spec', 'fixtures', 'socure_docv')}/*.json"].map do |fixture_file|
            SocureFixture.new(
              name: File.basename(fixture_file),
              body: File.read(fixture_file),
            )
          end
      end

      def update_fixture_body(new_fixture_name)
        @selected_fixture_body = nil

        body = @fixtures.find do |fixture|
          fixture.name == new_fixture_name
        end&.body

        @selected_fixture_body = JSON.parse(body, symbolize_names: true) if body
      end

      def body_data(path)
        selected_fixture_body&.dig(*path)
      end

      def set_body_data(path, new_value)
        selected_fixture_body&.dig(*path[0..-2])&.store(path[-1], new_value)
      end

      def webhook_endpoint
        Rails.application.routes.url_helpers.api_webhooks_socure_event_url
      end

      def hit_webhook(event_type:)
        Faraday.post webhook_endpoint do |req|
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
    end
  end
end
