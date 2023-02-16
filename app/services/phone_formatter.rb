module PhoneFormatter
  def self.format(phone, country_code: nil)
    Phonelib.parse(phone, country_code)&.international
  end
end
