# frozen_string_literal: true

module PhoneFormatter
  DEFAULT_COUNTRY = 'US'

  def self.format(phone, country_code: nil)
    country_code = DEFAULT_COUNTRY if country_code.nil? && !phone&.start_with?('+')
    Phonelib.parse(phone, country_code)&.international
  end

  def self.mask(phone)
    return '' if phone.blank?

    formatted = Phonelib.parse(phone).national
    # Mask all but the last four digits, preserving spaces and punctuation.
    digits_to_mask = formatted.count('0-9') - 4

    formatted.gsub(/\d/) do |digit|
      if digits_to_mask.positive?
        digits_to_mask -= 1
        '*'
      else
        digit
      end
    end
  end
end
