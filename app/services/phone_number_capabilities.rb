class PhoneNumberCapabilities
  INTERNATIONAL_CODES = YAML.load_file(
    Rails.root.join('config', 'country_dialing_codes.yml'),
  ).freeze

  attr_reader :phone, :phone_confirmed

  def initialize(phone, phone_confirmed:)
    @phone = phone
    @phone_confirmed = phone_confirmed
  end

  # @param [Symbol] method
  def supports?(method)
    case method
    when :sms
      supports_sms?
    when :voice
      supports_voice?
    else
      raise "Unknown method=#{method}"
    end
  end

  # @param [Array<Symbol>] methods
  def supports_all?(methods)
    methods.all? { |method| supports?(method) }
  end

  def sms_only?
    supports_sms? && !supports_voice?
  end

  def supports_sms?
    return false if country_code_data.nil?
    supports_sms = country_code_data['supports_sms']

    supports_sms_unconfirmed = country_code_data.fetch(
      'supports_sms_unconfirmed',
      supports_sms,
    )

    supports_sms_unconfirmed || (
      supports_sms && phone_confirmed
    )
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
    @parsed_phone ||= Phonelib.parse(phone)
  end
end
