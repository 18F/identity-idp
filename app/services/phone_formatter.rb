# frozen_string_literal: true

module PhoneFormatter
  DEFAULT_COUNTRY = 'US'

  def self.format(phone, country_code: nil)
    country_code = DEFAULT_COUNTRY if country_code.nil? && !phone&.start_with?('+')
    Phonelib.parse(phone, country_code)&.international
  end

  def self.mask(phone)
    return '' if phone.blank?

    parsed_phone = Phonelib.parse(phone)
    formatted = parsed_phone.national.to_s
    return '' if formatted.blank?

    national_digits = parsed_phone.raw_national.to_s
    if formatted.count('0-9') > national_digits.length
      formatted_without_country_code = parsed_phone.international.to_s.sub(
        /\A\+#{Regexp.escape(parsed_phone.country_code)}\s*/,
        '',
      )
      if formatted_without_country_code.gsub(/\D/, '') == national_digits
        formatted = formatted_without_country_code
      end
    end

    digits_to_mask = [formatted.count('0-9') - 4, 0].max

    formatted.gsub(/\d/) do |digit|
      next digit if digits_to_mask.zero?

      digits_to_mask -= 1
      '*'
    end
  end
end
