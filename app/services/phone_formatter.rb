# frozen_string_literal: true

module PhoneFormatter
  DEFAULT_COUNTRY = 'US'

  def self.format(phone, country_code: nil)
    country_code = DEFAULT_COUNTRY if country_code.nil? && !phone&.start_with?('+')
    Phonelib.parse(phone, country_code)&.international
  end

  def self.mask(phone)
    return '' if phone.blank?

    formatted = Phonelib.parse(phone).national.to_s
    return '' if formatted.blank?

    visible_digits = 0

    formatted.reverse.chars.map do |char|
      next char unless char.match?(/\d/)

      visible_digits += 1
      visible_digits <= 4 ? char : '*'
    end.reverse.join
  end
end
