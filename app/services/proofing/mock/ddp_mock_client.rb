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
                          :zipcode

      optional_attributes :address2, :phone, :email

      stage :resolution

      TRANSACTION_ID = 'ddp-mock-transaction-id-123'

      # Trigger the "REJECT" status
      REJECT_STATUS_SSN = '666-77-8888'

      # Trigger the "REVIEW" status
      REVIEW_STATUS_SSN = '666-77-9999'

      # Trigger a nil status
      NIL_STATUS_SSN = '666-77-0000'

      proof do |applicant, result|
        result.transaction_id = TRANSACTION_ID
        result.review_status = case SsnFormatter.format(applicant[:ssn])
        when REJECT_STATUS_SSN
          'reject'
        when REVIEW_STATUS_SSN
          'review'
        when NIL_STATUS_SSN
          nil
        else
          'pass'
        end
      end
    end
  end
end
