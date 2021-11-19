class PhoneInputComponent < BaseComponent
  attr_reader :form, :required, :allowed_countries
  alias_method :f, :form

  def initialize(form:, allowed_countries: nil, required: false)
    @allowed_countries = allowed_countries
    @form = form
    @required = required
  end

  def supported_country_codes
    codes = PhoneNumberCapabilities::INTERNATIONAL_CODES.keys
    codes &= allowed_countries if allowed_countries
    codes
  end

  def international_phone_codes
    supported_country_codes.
      map do |code_key|
        code_data = PhoneNumberCapabilities::INTERNATIONAL_CODES[code_key]
        [
          international_phone_code_label(code_data),
          code_key,
          { data: international_phone_codes_data(code_data) },
        ]
      end.
      sort_by do |label, code_key, _data|
        # Sort alphabetically by label, but put the US first in the list
        [code_key == 'US' ? -1 : 1, label]
      end
  end

  def css_class
    classes = ['margin-bottom-4']
    classes << 'phone-input--single-country' if supported_country_codes.size == 1
    classes
  end

  private

  def international_phone_code_label(code_data)
    "#{code_data['name']} +#{code_data['country_code']}"
  end

  def international_phone_codes_data(code_data)
    {
      supports_sms: code_data['supports_sms'],
      supports_voice: code_data['supports_voice'],
      country_code: code_data['country_code'],
      country_name: code_data['name'],
    }
  end
end
