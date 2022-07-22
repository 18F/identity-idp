module UspsInPersonProofing
  module Mock
    class Proofer
      def request_enroll(_applicant)
        JSON.load_file(
          Rails.root.join('spec/fixtures/usps_ipp_responses/request_enroll_response.json'),
        )
      end
      def request_facilities(location)
        JSON.load_file(
          Rails.root.join('spec/fixtures/usps_ipp_responses/request_facilities_response.json')
        )
      end
      def request_pilot_facilities
        JSON.load_file(
          Rails.root.join('spec/fixtures/usps_ipp_responses/request_facilities_response.json')
        )
      end
    end
  end
end
