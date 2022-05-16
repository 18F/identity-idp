module Idp
  module Constants
    DEFAULT_IAL = 1
    IAL_MAX = 0
    IAL1 = 1
    IAL2 = 2
    IAL2_STRICT = 22

    DEFAULT_AAL = 0
    AAL1 = 1
    AAL2 = 2
    AAL3 = 3

    DEFAULT_MOCK_PII_FROM_DOC = {
      first_name: 'FAKEY',
      middle_name: nil,
      last_name: 'MCFAKERSON',
      address1: '1 FAKE RD',
      address2: nil,
      city: 'GREAT FALLS',
      state: 'MT',
      zipcode: '59010',
      dob: '1938-10-06',
      state_id_number: '1111111111111',
      state_id_jurisdiction: 'ND',
      state_id_type: 'drivers_license',
      state_id_expiration: '2099-12-31',
      phone: nil,
    }.freeze
  end
end
