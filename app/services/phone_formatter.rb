module PhoneFormatter
  DEFAULT_COUNTRY = 'US'.freeze

  def self.format(phone, country_code: nil)
    country_code = DEFAULT_COUNTRY if country_code.nil? && !phone&.start_with?('+')
    Phonelib.parse(phone, country_code)&.international
  end

  def self.mask(phone)
    return '' if phone.blank?

    formatted = Phonelib.parse(phone).national
    formatted[0..-5].gsub(/\d/, '*') + formatted[-4..-1]
  end
end
