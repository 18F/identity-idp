module Proofing
  module Mock
    class DdpMockClient
      class << self
        def vendor_name
          'DdpMock'
        end

        def required_attributes
          %I[threatmetrix_session_id
             state_id_number
             first_name
             last_name
             dob
             ssn
             address1
             city
             state
             zipcode
             request_ip]
        end

        def optional_attributes
          %I[address2 phone email uuid_prefix]
        end

        def stage
          :resolution
        end
      end

      FIXTURES_DIR = Rails.root.join(
        'spec',
        'fixtures',
        'proofing',
        'lexis_nexis',
        'ddp',
      )
      TRANSACTION_ID = 'ddp-mock-transaction-id-123'

      def initialize(response_fixture_file: 'successful_response.json')
        @response_fixture_file = File.expand_path(response_fixture_file, FIXTURES_DIR)
      end

      def proof(applicant)
        result = Proofing::DdpResult.new
        result.transaction_id = TRANSACTION_ID

        review_status = review_status_for(session_id: applicant[:threatmetrix_session_id])
        response_body = response_body_json(review_status: review_status)

        result.review_status = review_status
        result.response_body = response_body

        result
      end

      def review_status_for(session_id:)
        device_status = DeviceProfilingBackend.new.profiling_result(session_id) || 'pass'

        case device_status
        when 'no_result'
          return nil
        when 'reject', 'review', 'pass'
          device_status
        end
      end

      def response_body_json(review_status:)
        json = File.read(@response_fixture_file)

        JSON.parse(json).tap do |json_body|
          json_body['review_status'] = review_status
        end
      end
    end
  end
end
