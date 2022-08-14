module Proofing
  module Mock
    class DdpMockClient < Proofing::Base
      vendor_name 'DdpMock'

      required_attributes :first_name,
                          :last_name,
                          :dob,
                          :ssn,
                          :address1,
                          :city,
                          :state,
                          :zipcode

      optional_attributes :address2, :phone, :state_id_number

      stage :resolution

      stage :resolution

      TRANSACTION_ID = 'ddp-mock-transaction-id-123'

      proof do |applicant, result|
        result.transaction_id = TRANSACTION_ID
      end
    end
  end
end
