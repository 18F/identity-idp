module Proofing
  module Mock
    class DdpMockClient < Proofing::Base
      vendor_name 'DdpMock'

      required_attributes :threatmetrix_session_id,
                          :state_id_number,
                          :first_name,
                          :last_name,
                          :dob,
                          :ssn,
                          :address1,
                          :city,
                          :state,
                          :zipcode,
                          :request_ip

      optional_attributes :address2, :phone, :email, :uuid_prefix

      stage :resolution

      TRANSACTION_ID = 'ddp-mock-transaction-id-123'

      proof do |applicant, result|
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
