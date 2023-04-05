module Idp
  module Constants
    UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
    module Vendors
      ACUANT = 'acuant'
      LEXIS_NEXIS = 'lexis_nexis'
      MOCK = 'mock'
      USPS = 'usps'
      AAMVA = 'aamva'
    end

    # US State and Territory codes are
    # taken from the FIPS standard, which
    # can be found at:
    # https://www.census.gov/library/reference/code-lists/ansi.html#state
    STATE_AND_TERRITORY_CODES = %w[
      AL
      AK
      AZ
      AR
      CA
      CO
      CT
      DE
      DC
      FL
      GA
      HI
      ID
      IL
      IN
      IA
      KS
      KY
      LA
      ME
      MD
      MA
      MI
      MN
      MS
      MO
      MT
      NE
      NV
      NH
      NJ
      NM
      NY
      NC
      ND
      OH
      OK
      OR
      PA
      RI
      SC
      SD
      TN
      TX
      UT
      VT
      VA
      WA
      WV
      WI
      WY
      AS
      GU
      MP
      PR
      VI
    ].to_set.freeze

    DEFAULT_IAL = 1
    IAL_MAX = 0
    IAL1 = 1
    IAL2 = 2

    DEFAULT_AAL = 0
    AAL1 = 1
    AAL2 = 2
    AAL3 = 3

    MOCK_IDV_APPLICANT = {
      address1: '1 FAKE RD',
      address2: nil,
      city: 'GREAT FALLS',
      dob: '1938-10-06',
      first_name: 'FAKEY',
      last_name: 'MCFAKERSON',
      middle_name: nil,
      phone: nil,
      state: 'MT',
      state_id_expiration: '2099-12-31',
      state_id_issued: '2019-12-31',
      state_id_jurisdiction: 'ND',
      state_id_number: '1111111111111',
      state_id_type: 'drivers_license',
      zipcode: '59010',
    }.freeze

    MOCK_IDV_APPLICANT_STATE_ID_ADDRESS = MOCK_IDV_APPLICANT.merge(
      state_id_address1: '123 Way St',
      state_id_address2: '2nd Address Line',
      state_id_city: 'Best City',
      state_id_zipcode: '12345',
    ).freeze

    MOCK_IDV_APPLICANT_WITH_SSN = MOCK_IDV_APPLICANT.merge(ssn: '900-66-1234').freeze

    MOCK_IDV_APPLICANT_WITH_PHONE = MOCK_IDV_APPLICANT_WITH_SSN.merge(phone: '12025551212').freeze

    MOCK_IDV_APPLICANT_FULL_STATE_ID_JURISDICTION = 'North Dakota'
    MOCK_IDV_APPLICANT_FULL_STATE = 'Montana'

    MOCK_IDV_APPLICANT_WITH_STATE_ID_ADDRESS = MOCK_IDV_APPLICANT_WITH_SSN.merge(
      {
        same_address_as_id: 'false',
        state_id_address1: '73 FAKE CIRCLE',
        state_id_address2: '#2',
        state_id_city: 'LESSER FALLS',
        state_id_zipcode: '59022',
      },
    ).freeze
  end
end
