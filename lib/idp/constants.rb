module Idp
  module Constants
    module Vendors
      ACUANT = 'acuant'
      LEXIS_NEXIS = 'lexisnexis'
      MOCK = 'mock'
      USPS = 'usps'
    end

    DEFAULT_IAL = 1
    IAL_MAX = 0
    IAL1 = 1
    IAL2 = 2
    IAL2_STRICT = 22

    DEFAULT_AAL = 0
    AAL1 = 1
    AAL2 = 2
    AAL3 = 3

    MOCK_IDV_APPLICANT = {
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

    MOCK_IDV_APPLICANT_WITH_SSN = MOCK_IDV_APPLICANT.merge(ssn: '900-66-1234').freeze

    MOCK_IDV_APPLICANT_WITH_PHONE = MOCK_IDV_APPLICANT_WITH_SSN.merge(phone: '12025551212').freeze

    MOCK_IDV_APPLICANT_FULL_STATE_ID_JURISDICTION = 'North Dakota'
    MOCK_IDV_APPLICANT_FULL_STATE = 'Montana'

    MOCK_IDV_PILOT_LOCATIONS = [{"address"=>"606 E JUNEAU AVE", "city"=>"MILWAUKEE", "distance"=>"0.54 mi", "name"=>"JUNEAU", 
    "phone"=>"414-289-0809", "saturday_hours"=>"9:00 AM - 3:00 PM", "state"=>"WI", "sunday_hours"=>"Closed", 
    "weekday_hours"=>"9:00 AM - 6:00 PM", "zip_code_4"=>"9998", "zip_code_5"=>"53202"}, 
    {"address"=>"345 W SAINT PAUL AVE", "city"=>"MILWAUKEE", "distance"=>"0.66 mi", "name"=>"MILWAUKEE", 
    "phone"=>"414-270-2308", "saturday_hours"=>"Closed", "state"=>"WI", "sunday_hours"=>"Closed", 
    "weekday_hours"=>"9:00 AM - 8:00 PM", "zip_code_4"=>"3099", "zip_code_5"=>"53203"}, 
    {"address"=>"1301 N 12TH ST", "city"=>"MILWAUKEE", "distance"=>"1.38 mi", "name"=>"HILLTOP", 
    "phone"=>"414-342-3335", "saturday_hours"=>"8:30 AM - 12:00 PM", "state"=>"WI", 
    "sunday_hours"=>"Closed", "weekday_hours"=>"8:30 AM - 5:00 PM", "zip_code_4"=>"9998", 
    "zip_code_5"=>"53205"}, {"address"=>"1416 S 11TH ST", "city"=>"MILWAUKEE", "distance"=>"1.86 mi", 
    "name"=>"HARBOR", "phone"=>"414-671-4581", "saturday_hours"=>"8:30 AM - 12:00 PM", "state"=>"WI", 
    "sunday_hours"=>"Closed", "weekday_hours"=>"8:00 AM - 5:00 PM", "zip_code_4"=>"9998", "zip_code_5"=>"53204"}, 
    {"address"=>"2650 N DR MARTIN LUTHER KING JR DR", "city"=>"MILWAUKEE", "distance"=>"2.03 mi", 
    "name"=>"DR MARTIN LUTHER KING JR", "phone"=>"414-562-1449", "saturday_hours"=>"9:00 AM - 12:00 PM", "state"=>"WI", 
    "sunday_hours"=>"Closed", "weekday_hours"=>"9:00 AM - 4:30 PM", "zip_code_4"=>"9998", "zip_code_5"=>"53212"}, 
    {"address"=>"2656 N TEUTONIA AVE", "city"=>"MILWAUKEE", "distance"=>"2.37 mi", "name"=>"TEUTONIA", "phone"=>"414-562-3117", 
    "saturday_hours"=>"9:00 AM - 12:00 PM", "state"=>"WI", "sunday_hours"=>"Closed", "weekday_hours"=>"8:30 AM - 4:30 PM", 
    "zip_code_4"=>"9998", "zip_code_5"=>"53206"}, {"address"=>"3421 W VLIET ST", "city"=>"MILWAUKEE", "distance"=>"2.88 mi", 
    "name"=>"MID CITY", "phone"=>"414-342-3339", "saturday_hours"=>"9:00 AM - 12:00 PM", "state"=>"WI", "sunday_hours"=>"Closed", 
    "weekday_hours"=>"9:00 AM - 5:00 PM", "zip_code_4"=>"9998", "zip_code_5"=>"53208"}, {"address"=>"1620 E CAPITOL DR", 
    "city"=>"MILWAUKEE", "distance"=>"3.61 mi", "name"=>"SHOREWOOD", "phone"=>"414-332-2241", 
    "saturday_hours"=>"9:00 AM - 1:00 PM", "state"=>"WI", "sunday_hours"=>"Closed", "weekday_hours"=>"8:30 AM - 6:00 PM", 
    "zip_code_4"=>"9998", "zip_code_5"=>"53211"}, {"address"=>"1603 E OKLAHOMA AVE", "city"=>"MILWAUKEE", "distance"=>"3.63 mi", 
    "name"=>"BAY VIEW SAINT FRANCIS", "phone"=>"414-481-0204", "saturday_hours"=>"9:00 AM - 12:00 PM", "state"=>"WI", 
    "sunday_hours"=>"Closed", "weekday_hours"=>"8:00 AM - 5:00 PM", "zip_code_4"=>"9998", "zip_code_5"=>"53207"}, 
    {"address"=>"4300 W LINCOLN AVE", "city"=>"MILWAUKEE", "distance"=>"4.19 mi", "name"=>"WEST MILWAUKEE", 
    "phone"=>"414-643-0443", "saturday_hours"=>"9:30 AM - 2:00 PM", "state"=>"WI", "sunday_hours"=>"Closed", 
    "weekday_hours"=>"9:00 AM - 6:00 PM", "zip_code_4"=>"5012", "zip_code_5"=>"53219"}]
  end
end
