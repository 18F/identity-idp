module ArcgisApi
  module Mock
    class Geocoder < ArcgisApi::Geocoder
      def faraday
        super do |conn|
          conn.adapter :test do |stub|
            stub_generate_token(stub)
            stub_suggestions(stub)
            stub_address_candidates(stub)
          end
        end
      end

      private

      def stub_generate_token(stub)
        stub.post(GENERATE_TOKEN_ENDPOINT) do |env|
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

      def stub_suggestions(stub)
        stub.get(SUGGEST_ENDPOINT) do |env|
          [
            200,
            { 'Content-Type': 'application/json' },
            ArcgisApi::Mock::Fixtures.request_suggestions_response,
          ]
        end
      end

      def stub_address_candidates(stub)
        stub.get(ADDRESS_CANDIDATES_ENDPOINT) do |env|
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
