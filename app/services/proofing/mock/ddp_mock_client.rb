module Proofing
  module Mock
    class DdpMockClient
      # class << self
      #   def vendor_name
      #     'DdpMock'
      #   end

      #   def required_attributes
      #     %I[threatmetrix_session_id
      #        state_id_number
      #        first_name
      #        last_name
      #        dob
      #        ssn
      #        address1
      #        city
      #        state
      #        zipcode
      #        request_ip]
      #   end

      #   def optional_attributes
      #     %I[address2 phone email uuid_prefix]
      #   end

      #   def stage
      #     :resolution
      #   end
      # end

      TRANSACTION_ID = 'ddp-mock-transaction-id-123'

      def proof(applicant)
        result = Proofing::LexisNexis::Ddp::VerificationRequest.new(
          config: Proofing::LexisNexis::Ddp::Proofer::Config.new,
          applicant: applicant,
        ).send
        result.transaction_id = TRANSACTION_ID

        response_body = File.read(
          Rails.root.join(
            'spec', 'fixtures', 'proofing', 'lexis_nexis', 'ddp', 'successful_response.json'
          ),
        )

        status = review_status(session_id: applicant[:threatmetrix_session_id])

        result.review_status = status
        result.response_body = JSON.parse(response_body).tap do |json_body|
          json_body['review_status'] = status
        end

        result
      end

      def review_status(session_id:)
        device_status = DeviceProfilingBackend.new.profiling_result(session_id)

        case device_status
        when 'no_result'
          return nil
        when 'reject', 'review', 'pass'
          device_status
        end
      end
    end
  end
end
