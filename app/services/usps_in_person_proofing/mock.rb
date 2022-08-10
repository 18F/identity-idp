require './spec/support/usps_ipp_fixtures'

module UspsInPersonProofing
  module Mock
    class Proofer
      def request_enroll(applicant)
        # timeout
        if applicant[:first_name] == 'usps oot'
          raise Faraday::TimeoutError.new
        elsif applicant[:first_name] == 'usps 400'
          # Usps 400 response
          res = JSON.parse(::UspsIppFixtures.request_enroll_bad_request_response)
        elsif applicant[:first_name] == 'usps 500'
          # Usps 500 response
          res = JSON.parse(::UspsIppFixtures.request_enroll_internal_failed_response)
        elsif applicant[:first_name] == 'usps invalid'
          # no enrollment code
          res = JSON.parse(::UspsIppFixtures.request_enroll_invalid_response)
        else
          res = JSON.parse(::UspsIppFixtures.request_enroll_response)
        end

        Response::RequestEnrollResponse.new(res)
      end

      def request_facilities(_location)
        JSON.load_file(
          Rails.root.join(
            'spec',
            'fixtures',
            'usps_ipp_responses',
            'request_facilities_response.json',
          ),
        )
      end

      def request_pilot_facilities
        JSON.load_file(
          Rails.root.join(
            'config',
            'ipp_pilot_usps_facilities.json',
          ),
        )
      end
    end
  end
end
