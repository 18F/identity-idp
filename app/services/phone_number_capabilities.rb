class PhoneNumberCapabilities
  INTERNATIONAL_CODES = YAML.load_file(
    Rails.root.join('config', 'country_dialing_codes.yml'),
  ).freeze

  attr_reader :phone

  def initialize(phone)
    @phone = phone
  end

  def sms_only?
    supports_sms? && !supports_voice?
  end

  def supports_sms?
    return false if country_code_data.nil?
    country_code_data['supports_sms']
  end

  def supports_voice?
    return false if country_code_data.nil?
    country_code_data['supports_voice']
  end

  def unsupported_location
    country_code_data['name'] if country_code_data
  end

  private

  def country_code_data
    INTERNATIONAL_CODES[two_letter_country_code]
  end

  def two_letter_country_code
    parsed_phone.country
  end

  def parsed_phone
    blank_default_country = '' # override Phonelib.default_country so it doesn't default to US
    Phonelib.parse(phone, blank_default_country)
  end
end
