module FormHelper
  def state_id_types
    Idv::FormStateIdValidator::STATE_ID_TYPES.map do |state_id_type|
      [t("idv.form.state_id_type.#{state_id_type}"), state_id_type]
    end
  end

  # rubocop:disable MethodLength, WordArray
  # This method is single statement spread across many lines for readability
  def us_states_territories
    [
      ['Alabama', 'AL'],
      ['Alaska', 'AK'],
      ['American Samoa', 'AS'],
      ['Arizona', 'AZ'],
      ['Arkansas', 'AR'],
      ['Armed Forces Americas', 'AA'],
      ['Armed Forces Others', 'AE'],
      ['Armed Forces Pacific', 'AP'],
      ['California', 'CA'],
      ['Colorado', 'CO'],
      ['Connecticut', 'CT'],
      ['Delaware', 'DE'],
      ['District of Columbia', 'DC'],
      ['Florida', 'FL'],
      ['Georgia', 'GA'],
      ['Guam', 'GU'],
      ['Hawaii', 'HI'],
      ['Idaho', 'ID'],
      ['Illinois', 'IL'],
      ['Indiana', 'IN'],
      ['Iowa', 'IA'],
      ['Kansas', 'KS'],
      ['Kentucky', 'KY'],
      ['Louisiana', 'LA'],
      ['Maine', 'ME'],
      ['Maryland', 'MD'],
      ['Massachusetts', 'MA'],
      ['Michigan', 'MI'],
      ['Minnesota', 'MN'],
      ['Mississippi', 'MS'],
      ['Missouri', 'MO'],
      ['Montana', 'MT'],
      ['Nebraska', 'NE'],
      ['Nevada', 'NV'],
      ['New Hampshire', 'NH'],
      ['New Jersey', 'NJ'],
      ['New Mexico', 'NM'],
      ['New York', 'NY'],
      ['North Carolina', 'NC'],
      ['North Dakota', 'ND'],
      ['Northern Mariana Islands', 'MP'],
      ['Ohio', 'OH'],
      ['Oklahoma', 'OK'],
      ['Oregon', 'OR'],
      ['Pennsylvania', 'PA'],
      ['Puerto Rico', 'PR'],
      ['Rhode Island', 'RI'],
      ['South Carolina', 'SC'],
      ['South Dakota', 'SD'],
      ['Tennessee', 'TN'],
      ['Texas', 'TX'],
      ['United States Minor Outlying Islands', 'UM'],
      ['Utah', 'UT'],
      ['Vermont', 'VT'],
      ['Virgin Islands', 'VI'],
      ['Virginia', 'VA'],
      ['Washington', 'WA'],
      ['West Virginia', 'WV'],
      ['Wisconsin', 'WI'],
      ['Wyoming', 'WY'],
    ]
  end
  # rubocop:enable MethodLength, WordArray

  def international_phone_codes
    PhoneNumberCapabilities::INTERNATIONAL_CODES.map do |key, value|
      [
        international_phone_code_label(value),
        key,
        { data: international_phone_codes_data(value) },
      ]
    end
  end

  def unsupported_area_codes
    PhoneNumberCapabilities::VOICE_UNSUPPORTED_US_AREA_CODES
  end

  def supported_jurisdictions
    Idv::FormJurisdictionValidator::SUPPORTED_JURISDICTIONS
  end

  def state_name_for_abbrev(abbrev)
    us_states_territories.find([]) { |state| state.second == abbrev }.first
  end

  private

  def international_phone_code_label(code_data)
    "#{code_data['name']} +#{code_data['country_code']}"
  end

  def international_phone_codes_data(code_data)
    {
      sms_only: code_data['sms_only'],
      country_code: code_data['country_code'],
      country_name: code_data['name'],
    }
  end
end
