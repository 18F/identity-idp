module Idp
  module Constants
    AVAILABLE_LOCALES = %w[en es fr zh]
    UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

    KMS_LOG_FILENAME = 'kms.log'
    WORKER_LOG_FILENAME = 'workers.log'
    EVENT_LOG_FILENAME = 'events.log'
    TELEPHONY_LOG_FILENAME = 'telephony.log'

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

    MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION = 'ND'
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
      state_id_jurisdiction: MOCK_IDV_APPLICANT_STATE_ID_JURISDICTION,
      state_id_number: '1111111111111',
      state_id_type: 'drivers_license',
      zipcode: '59010',
      same_address_as_id: nil,
    }.freeze

    MOCK_IPP_APPLICANT = {
      first_name: 'FAKEY',
      last_name: 'MCFAKERSON',
      dob: '1938-10-06',
      identity_doc_address1: '123 Way St',
      identity_doc_address2: '2nd Address Line',
      identity_doc_city: 'Best City',
      identity_doc_zipcode: '12345',
      state_id_jurisdiction: 'Virginia',
      identity_doc_address_state: 'VA',
      state_id_number: '1111111111111',
      same_address_as_id: 'true',
    }.freeze

    MOCK_IPP_APPLICANT_SAME_ADDRESS_AS_ID_FALSE = MOCK_IPP_APPLICANT.merge(
      same_address_as_id: 'false',
    ).freeze

    MOCK_IDV_APPLICANT_WITH_SSN = MOCK_IDV_APPLICANT.merge(ssn: '900-66-1234').freeze

    MOCK_IDV_APPLICANT_STATE_ID_ADDRESS = MOCK_IDV_APPLICANT_WITH_SSN.merge(
      identity_doc_address1: '123 Way St',
      identity_doc_address2: '2nd Address Line',
      identity_doc_city: 'Best City',
      identity_doc_zipcode: '12345',
      identity_doc_address_state: 'VA',
      same_address_as_id: 'false',
    ).freeze

    # Use this as the default applicant for in person proofing
    MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID = MOCK_IDV_APPLICANT_WITH_SSN.merge(
      identity_doc_address1: MOCK_IDV_APPLICANT_WITH_SSN[:address1],
      identity_doc_address2: MOCK_IDV_APPLICANT_WITH_SSN[:address2],
      identity_doc_city: MOCK_IDV_APPLICANT_WITH_SSN[:city],
      identity_doc_zipcode: MOCK_IDV_APPLICANT_WITH_SSN[:zipcode],
      identity_doc_address_state: MOCK_IDV_APPLICANT_WITH_SSN[:state],
      same_address_as_id: 'true',
    ).freeze

    MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_NO_SSN = MOCK_IDV_APPLICANT.merge(
      identity_doc_address1: MOCK_IDV_APPLICANT[:address1],
      identity_doc_address2: MOCK_IDV_APPLICANT[:address2],
      identity_doc_city: MOCK_IDV_APPLICANT[:city],
      identity_doc_zipcode: MOCK_IDV_APPLICANT[:zipcode],
      identity_doc_address_state: MOCK_IDV_APPLICANT[:state],
      same_address_as_id: 'true',
    ).freeze

    MOCK_IDV_APPLICANT_WITH_PHONE = MOCK_IDV_APPLICANT_WITH_SSN.merge(phone: '12025551212').freeze

    MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_PHONE =
      MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID.merge(phone: '12025551212').freeze

    MOCK_IDV_APPLICANT_FULL_STATE_ID_JURISDICTION = 'North Dakota'
    MOCK_IDV_APPLICANT_FULL_STATE = 'Montana'
    MOCK_IDV_APPLICANT_FULL_IDENTITY_DOC_ADDRESS_STATE = 'Virginia'
    MOCK_IDV_APPLICANT_STATE = 'MT'
  end
end
