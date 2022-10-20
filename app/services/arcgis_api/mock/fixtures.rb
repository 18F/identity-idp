module ArcgisApi
  module Mock
    class Fixtures
      def self.request_suggestions_response
        load_response_fixture('request_suggestions_response.json')
      end

      def self.load_response_fixture(filename)
        path = File.join(
          File.dirname(__FILE__),
          'responses',
          filename,
        )
        File.read(path)
      end
    end
  end
end
