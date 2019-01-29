class PhoneNumberCapabilities
  INTERNATIONAL_CODES = YAML.load_file(
    Rails.root.join('config', 'country_dialing_codes.yml'),
  ).freeze

  attr_reader :phone

  def initialize(phone)
    @phone = phone
  end

  def sms_only?
    return true if country_code_data.nil?
    country_code_data['sms_only']
  end

  def unsupported_location
    country_code_data['name'] if country_code_data
  end

  private

  def country_code_data
    @country_code_data ||= INTERNATIONAL_CODES.select do |key, _|
      key == two_letter_country_code
    end.values.first
  end

  def two_letter_country_code
    parsed_phone.country
  end

  def parsed_phone
    Phonelib.parse(phone)
  end
end
