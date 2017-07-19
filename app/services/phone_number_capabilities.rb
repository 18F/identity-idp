class PhoneNumberCapabilities
  VOICE_UNSUPPORTED_US_AREA_CODES = {
    '648' => 'American Samoa',
    '671' => 'Guam',
    '670' => 'Northern Mariana Islands',
    '340' => 'United States Virgin Islands',
  }.freeze

  attr_reader :phone

  def initialize(phone)
    @phone = phone
  end

  def sms_only?
    VOICE_UNSUPPORTED_US_AREA_CODES[area_code].present?
  end

  def unsupported_location
    VOICE_UNSUPPORTED_US_AREA_CODES[area_code]
  end

  private

  def area_code
    @area_code ||= Phony.split(Phony.normalize(phone, cc: '1')).second
  end
end
