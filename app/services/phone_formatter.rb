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

    digits = parsed_phone.raw_national.to_s.presence || formatted.gsub(/\D/, '')
    if formatted.count('0-9') > digits.length
      formatted = parsed_phone.international.to_s.delete_prefix(
        "+#{parsed_phone.country_code}",
      ).strip
    end

    digits_to_mask = [digits.length - 4, 0].max

    formatted.gsub(/\d/) do |digit|
      next digit if digits_to_mask.zero?

      digits_to_mask -= 1
      '*'
    end
  end
end
