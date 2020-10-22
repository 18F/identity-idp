module FormHelper
  # rubocop:disable Style/WordArray
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
  # rubocop:enable Style/WordArray

  def international_phone_codes
    PhoneNumberCapabilities::INTERNATIONAL_CODES.map do |key, value|
      [
        international_phone_code_label(value),
        key,
        { data: international_phone_codes_data(value) },
      ]
    end.sort_by do |label, key, _data|
      # Sort alphabetically by label, but put the US first
      [ key == 'US' ? -1 : 1, label ]
    end
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

  def validated_form_for(record, options = {}, &block)
    options[:data] ||= {}
    options[:data][:validate] = true
    javascript_pack_tag_once('form-validation')
    simple_form_for(record, options, &block)
  end
end
