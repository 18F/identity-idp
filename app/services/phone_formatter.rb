module PhoneFormatter
  DEFAULT_COUNTRY = 'US'.freeze

  def self.format(phone, country_code: nil)
    Phonelib.parse(phone, country_code || DEFAULT_COUNTRY)&.international
  end
end
