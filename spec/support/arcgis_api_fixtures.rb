module ArcgisApi
  module Mock
    class Fixtures
      def self.request_suggestions_response
        load_response_fixture('request_suggestions_response.json')
      end

      def self.request_suggestions_error
        load_response_fixture('request_suggestions_error.json')
      end

      def self.request_suggestions_error_html
        load_response_fixture('request_suggestions_error.html')
      end

      def self.load_response_fixture(filename)
        path = File.join(
          File.dirname(__FILE__),
          '../fixtures/arcgis_api_responses',
          filename,
        )
        File.read(path)
      end
    end
  end
end
