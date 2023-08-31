module UspsInPersonProofing
  module Mock
    class Proofer < UspsInPersonProofing::Proofer
      def request_enroll(applicant)
        case applicant['first_name']
        when 'usps waiting'
          # timeout
          raise Faraday::TimeoutError.new
        when 'usps client error'
          # usps 400 response
          body = JSON.parse(Fixtures.request_enroll_bad_request_response)
          response = { body: body, status: 400 }
          raise Faraday::BadRequestError.new('Bad request error', response)
        when 'usps server error'
          # usps 500 response
          body = JSON.parse(Fixtures.internal_server_error_response)
          response = { body: body, status: 500 }
          raise Faraday::ServerError.new('Internal server error', response)
        when 'usps invalid response'
          # no enrollment code
          res = JSON.parse(Fixtures.request_enroll_invalid_response)
        else
          # success
          res = JSON.parse(Fixtures.request_enroll_response)
        end

        Response::RequestEnrollResponse.new(res)
      end

      def request_facilities(_location)
        parse_facilities(JSON.parse(Fixtures.request_facilities_response))
      end

      def request_proofing_results(_unique_id, _enrollment_code)
        JSON.parse(Fixtures.request_passed_proofing_results_response)
      end
    end
  end
end
