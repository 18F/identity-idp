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

    # Count only digits so Phonelib's locale-specific separators stay intact
    # while we mask every leading digit except the last four.
    digits_to_mask = [formatted.count('0-9') - 4, 0].max

    formatted.gsub(/\d/) do |digit|
      next digit if digits_to_mask.zero?

      digits_to_mask -= 1
      '*'
    end
  end
end
