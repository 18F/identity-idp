module ArcgisApi
  module Mock
    # Mocking connection factory to generate stub response
    class MockConnectionFactory < ArcgisApi::ConnectionFactory
      attr_reader :stub
      def initialize
        @stub = Faraday::Adapter::Test::Stubs.new do |stub|
          stub_generate_token(stub)
          stub_suggestions(stub)
          stub_address_candidates(stub)
        end
      end

      def connection(url = nil, options = nil)
        super(url, options) do |con|
          con.adapter :test, stub
        end
      end

      private

      def stub_generate_token(stub)
        stub.post(IdentityConfig.store.arcgis_api_generate_token_url) do |_|
          [
            200,
            { 'Content-Type': 'application/json' },
            {
              token: '1234',
              expires: (Time.zone.now.to_f + 30) * 1000,
              ssl: true,
            }.to_json,
          ]
        end
      end

      def stub_suggestions(stub)
        stub.get(IdentityConfig.store.arcgis_api_suggest_url) do |_|
          [
            200,
            { 'Content-Type': 'application/json' },
            ArcgisApi::Mock::Fixtures.request_suggestions_response,
          ]
        end
      end

      def stub_address_candidates(stub)
        stub.get(IdentityConfig.store.arcgis_api_find_address_candidates_url) do |_|
          [
            200,
            { 'Content-Type': 'application/json' },
            ArcgisApi::Mock::Fixtures.request_candidates_response,
          ]
        end
      end
    end

    # Mocking Geocoder with injected mocking connection factory
    class Geocoder < ArcgisApi::Geocoder
      def initialize
        super(connection_factory: ArcgisApi::Mock::MockConnectionFactory.new)
      end
    end
  end
end
