module ArcgisApi
  module Mock
    class MockConnectionFactory < ArcgisApi::ConnectionFactory
      def connection(url = nil, options = nil)
        stubs = Faraday::Adapter::Test::Stubs.new do |stub|
          stub_generate_token(stub)
          stub_suggestions(stub)
          stub_address_candidates(stub)
        end
        super(url, options) do |con|
          con.adapter :test, stubs
        end
      end

      private

      def stub_generate_token(stub)
        stub.post(IdentityConfig.store.arcgis_api_generate_token_url) do |env|
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
        stub.get(IdentityConfig.store.arcgis_api_suggest_url) do |env|
          [
            200,
            { 'Content-Type': 'application/json' },
            ArcgisApi::Mock::Fixtures.request_suggestions_response,
          ]
        end
      end

      def stub_address_candidates(stub)
        stub.get(IdentityConfig.store.arcgis_api_find_address_candidates_url) do |env|
          [
            200,
            { 'Content-Type': 'application/json' },
            ArcgisApi::Mock::Fixtures.request_candidates_response,
          ]
        end
      end
    end

    class Geocoder < ArcgisApi::Geocoder
      def initialize
        super(token_keeper: nil, connection_factory: ArcgisApi::Mock::MockConnectionFactory.new)
      end
    end
  end
end
