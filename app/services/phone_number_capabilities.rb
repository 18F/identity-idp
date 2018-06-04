class PhoneNumberCapabilities
  VOICE_UNSUPPORTED_US_AREA_CODES = {
    '264' => 'Anguilla',
    '268' => 'Antigua and Barbuda',
    '242' => 'Bahamas',
    '246' => 'Barbados',
    '441' => 'Bermuda',
    '284' => 'British Virgin Islands',
    '345' => 'Cayman Islands',
    '767' => 'Dominica',
    '809' => 'Dominican Republic',
    '829' => 'Dominican Republic',
    '849' => 'Dominican Republic',
    '473' => 'Grenada',
    '876' => 'Jamaica',
    '664' => 'Montserrat',
    '869' => 'Saint Kitts and Nevis',
    '758' => 'Saint Lucia',
    '784' => 'Saint Vincent Grenadines',
    '868' => 'Trinidad and Tobago',
    '649' => 'Turks and Caicos Islands',
  }.freeze

  INTERNATIONAL_CODES = YAML.load_file(
    Rails.root.join('config', 'country_dialing_codes.yml')
  ).freeze

  attr_reader :phone

  def initialize(phone)
    @phone = phone
  end

  def sms_only?
    if international_code == '1'
      VOICE_UNSUPPORTED_US_AREA_CODES[area_code].present?
    elsif country_code_data
      country_code_data['sms_only']
    end
  end

  def unsupported_location
    if international_code == '1'
      VOICE_UNSUPPORTED_US_AREA_CODES[area_code]
    elsif country_code_data
      country_code_data['name']
    end
  end

  private

  def area_code
    @area_code ||= phone_number_components.second
  end

  def country_code_data
    @country_code_data ||= INTERNATIONAL_CODES.select do |_, value|
      value['country_code'] == international_code
    end.values.first
  end

  def international_code
    @international_code ||= phone_number_components.first
  end

  def phone_number_components
    return [] if phone.blank?

    @phone_number_components ||= Phony.split(
      PhonyRails.normalize_number(phone.to_s, default_country_code: :us).slice(1..-1)
    )
  end
end
