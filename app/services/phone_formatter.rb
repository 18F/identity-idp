module PhoneFormatter
  DEFAULT_COUNTRY = 'US'.freeze

  def self.format(phone, country_code: nil)
    country_code = DEFAULT_COUNTRY if country_code.nil? && !phone&.start_with?('+')
    Phonelib.parse(phone, country_code)&.international
  end
end
