module FormHelper
  # rubocop:disable Style/WordArray
  # This method is single statement spread across many lines for readability
  def us_states_territories
    [
      %w[Alabama AL],
      %w[Alaska AK],
      ['American Samoa', 'AS'],
      %w[Arizona AZ],
      %w[Arkansas AR],
      ['Armed Forces Americas', 'AA'],
      ['Armed Forces Others', 'AE'],
      ['Armed Forces Pacific', 'AP'],
      %w[California CA],
      %w[Colorado CO],
      %w[Connecticut CT],
      %w[Delaware DE],
      ['District of Columbia', 'DC'],
      %w[Florida FL],
      %w[Georgia GA],
      %w[Guam GU],
      %w[Hawaii HI],
      %w[Idaho ID],
      %w[Illinois IL],
      %w[Indiana IN],
      %w[Iowa IA],
      %w[Kansas KS],
      %w[Kentucky KY],
      %w[Louisiana LA],
      %w[Maine ME],
      %w[Maryland MD],
      %w[Massachusetts MA],
      %w[Michigan MI],
      %w[Minnesota MN],
      %w[Mississippi MS],
      %w[Missouri MO],
      %w[Montana MT],
      %w[Nebraska NE],
      %w[Nevada NV],
      ['New Hampshire', 'NH'],
      ['New Jersey', 'NJ'],
      ['New Mexico', 'NM'],
      ['New York', 'NY'],
      ['North Carolina', 'NC'],
      ['North Dakota', 'ND'],
      ['Northern Mariana Islands', 'MP'],
      %w[Ohio OH],
      %w[Oklahoma OK],
      %w[Oregon OR],
      %w[Pennsylvania PA],
      ['Puerto Rico', 'PR'],
      ['Rhode Island', 'RI'],
      ['South Carolina', 'SC'],
      ['South Dakota', 'SD'],
      %w[Tennessee TN],
      %w[Texas TX],
      ['United States Minor Outlying Islands', 'UM'],
      %w[Utah UT],
      %w[Vermont VT],
      ['Virgin Islands', 'VI'],
      %w[Virginia VA],
      %w[Washington WA],
      ['West Virginia', 'WV'],
      %w[Wisconsin WI],
      %w[Wyoming WY],
    ]
  end

  # rubocop:enable Style/WordArray

  def international_phone_codes
    codes =
      PhoneNumberCapabilities::INTERNATIONAL_CODES.map do |key, value|
        [
          international_phone_code_label(value),
          key,
          { data: international_phone_codes_data(value) },
        ]
      end

    # Sort alphabetically by label, but put the US first in the list
    codes.sort_by { |label, key, _data| [key == 'US' ? -1 : 1, label] }
  end

  def supported_country_codes
    PhoneNumberCapabilities::INTERNATIONAL_CODES.keys
  end

  private

  def international_phone_code_label(code_data)
    "#{code_data['name']} +#{code_data['country_code']}"
  end

  def international_phone_codes_data(code_data)
    {
      supports_sms: code_data['supports_sms'],
      supports_voice: code_data['supports_voice'],
      country_code: code_data['country_code'],
      country_name: code_data['name'],
    }
  end

  def validated_form_for(record, options = {}, &block)
    options[:data] ||= {}
    options[:data][:validate] = true
    javascript_packs_tag_once('form-validation')
    simple_form_for(record, options, &block)
  end
end
