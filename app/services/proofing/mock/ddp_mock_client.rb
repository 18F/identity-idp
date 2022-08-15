module Proofing
  module Mock
    class DdpMockClient < Proofing::Base
      vendor_name 'DdpMock'

      required_attributes :threatmetrix_session_id,
                          :state_id_number,
                          :email,
                          :first_name,
                          :last_name,
                          :dob,
                          :ssn,
                          :address1,
                          :city,
                          :state,
                          :zipcode

      optional_attributes :address2, :phone

      stage :resolution

      stage :resolution

      TRANSACTION_ID = 'ddp-mock-transaction-id-123'

      proof do |applicant, result|
        result.transaction_id = TRANSACTION_ID
      end
    end
  end
end
