module Idv
  module Proofer
    ATTRIBUTES = %i[
      uuid
      first_name last_name middle_name gen
      address1 address2 city state zipcode
      prev_address1 prev_address2 prev_city prev_state prev_zipcode
      ssn dob phone email
      ccn mortgage home_equity_line auto_loan
      bank_account bank_account_type bank_routing
      state_id_number state_id_type
    ]

    VENDORS = {
      resolution: Idv::Proofer::Mocks::ResolutionMock,
      state_id: Idv::Proofer::Mocks::StateIdMock,
      address: Idv::Proofer::Mocks::AddressMock
    }
  end
end
