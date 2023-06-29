module ArcgisApi
  module Mock
    class Geocoder < ArcgisApi::Geocoder
      def faraday
        super do |conn|
          conn.adapter :test do |stub|
            stub_generate_token(stub)
            stub_address_candidates(stub)
          end
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
              expires: 1234,
              ssl: true,
            }.to_json,
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
  end
end
