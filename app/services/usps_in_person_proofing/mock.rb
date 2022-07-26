module UspsInPersonProofing
  module Mock
    class Proofer
      def request_enroll(_applicant)
        res = JSON.load_file(
          Rails.root.join('spec/fixtures/usps_ipp_responses/request_enroll_response.json'),
        )
        Response::RequestEnrollResponse.new(res)
      end
    end
  end
end
