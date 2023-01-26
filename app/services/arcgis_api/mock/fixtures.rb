module ArcgisApi
  module Mock
    class Fixtures
      def self.request_suggestions_response
        generate_suggestions.to_json
      end

      def self.request_suggestions_error
        load_response_fixture('request_suggestions_error.json')
      end

      def self.request_suggestions_error_html
        load_response_fixture('request_suggestions_error.html')
      end

      def self.request_candidates_response
        generate_address_candidates.to_json
      end

      def self.request_candidates_empty_response
        load_response_fixture('request_candidates_response_empty.json')
      end

      def self.request_candidates_error
        load_response_fixture('request_candidates_error.json')
      end

      def self.load_response_fixture(filename)
        Rails.root.join('spec', 'fixtures', 'arcgis_responses', filename).read
      end

      private_class_method def self.generate_suggestions(count = 5)
        {
          suggestions: count.times do |index|
            {
              text: Faker::Address.full_address,
              magicKey: index,
              isCollection: false,
            }
          end,
        }
      end

      private_class_method def self.generate_address_candidates(count = 5)
        {
          candidates: Array.new(count) do
            {
              address: Faker::Address.full_address,
              location: {
                x: Faker::Address.latitude,
                y: Faker::Address.longitude,
              },
              attributes: {
                StAddr: Faker::Address.street_address,
                City: Faker::Address.city,
                RegionAbbr: Faker::Address.state_abbr,
                Postal: Faker::Address.zip,
              },
            }
          end,
        }
      end
    end
  end
end
