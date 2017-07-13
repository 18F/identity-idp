class PhoneFormatter
  DEFAULT_COUNTRY = 'US'.freeze

  def format(phone, country_code: nil)
    normalized_phone = if country_code
                         phone&.phony_normalized(country_code: country_code)
                       else
                         phone&.phony_normalized(default_country_code: DEFAULT_COUNTRY)
                       end
    normalized_phone&.phony_formatted(format: :international, spaces: ' ')
  end
end
