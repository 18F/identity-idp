class PhoneNumberCapabilities
  PINPOINT_SUPPORTED_COUNTRIES = YAML.load_file(
    Rails.root.join('config', 'pinpoint_supported_countries.yml'),
  ).freeze

  PINPOINT_OVERRIDES = YAML.load_file(
    Rails.root.join('config', 'pinpoint_overrides.yml'),
  ).freeze

  INTERNATIONAL_CODES = PINPOINT_SUPPORTED_COUNTRIES.deep_merge(PINPOINT_OVERRIDES).freeze

  attr_reader :phone, :phone_confirmed

  def initialize(phone, phone_confirmed:)
    @phone = phone
    @phone_confirmed = phone_confirmed
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

    supports_voice = country_code_data['supports_voice']
    supports_voice_unconfirmed = country_code_data.fetch(
      'supports_voice_unconfirmed',
      supports_voice,
    )

    supports_voice_unconfirmed || (
      supports_voice && phone_confirmed
    )
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
    Phonelib.parse(phone)
  end
end
