# frozen_string_literal: true

module UspsInPersonProofing
  module Mock
    class Proofer < UspsInPersonProofing::Proofer
      def request_enroll(applicant, is_enhanced_ipp)
        case applicant['first_name']
        when 'usps waiting'
          # timeout
          raise Faraday::TimeoutError.new
        when 'usps client error'
          # usps 400 response
          body = JSON.parse(Fixtures.request_enroll_bad_request_response)
          response = { body: body, status: 400 }
          raise Faraday::BadRequestError.new('Bad request error', response)
        when 'usps sponsor id error'
          # usps 400 response for Sponsor ID is not External IPP client
          body = JSON.parse(Fixtures.request_enroll_bad_sponsor_id_request_response)
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

        if is_enhanced_ipp
          res = JSON.parse(Fixtures.request_enroll_response_enhanced_ipp)
        end
        Response::RequestEnrollResponse.new(res)
      end

      def request_facilities(location, is_enhanced_ipp)
        if location['address'] == 'usps waiting'
          body = JSON.parse(Fixtures.internal_server_error_response)
          response = { body: body, status: 500 }
          raise Faraday::TimeoutError.new('Timeout error', response)
        elsif is_enhanced_ipp
          parse_facilities(JSON.parse(Fixtures.request_enhanced_ipp_facilities_response))
        else
          parse_facilities(JSON.parse(Fixtures.request_facilities_response))
        end
      end

      def request_proofing_results(enrollment)
        if enrollment.days_to_due_date.negative? && enrollment.enhanced_ipp?
          body = JSON.parse(Fixtures.request_expired_enhanced_ipp_results_response)
          response = { body: body, status: 400 }
          raise Faraday::BadRequestError.new('Bad request error', response)
        else
          JSON.parse(Fixtures.request_passed_proofing_results_response)
        end
      end
    end
  end
end
