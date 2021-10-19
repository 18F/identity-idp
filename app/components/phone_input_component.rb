class PhoneInputComponent < BaseComponent
  attr_reader :form, :required
  alias_method :f, :form

  def initialize(form:, required: false)
    @form = form
    @required = required
  end

  def supported_country_codes
    PhoneNumberCapabilities::INTERNATIONAL_CODES.keys
  end

  def international_phone_codes
    codes = PhoneNumberCapabilities::INTERNATIONAL_CODES.map do |key, value|
      [
        international_phone_code_label(value),
        key,
        { data: international_phone_codes_data(value) },
      ]
    end

    # Sort alphabetically by label, but put the US first in the list
    codes.sort_by do |label, key, _data|
      [key == 'US' ? -1 : 1, label]
    end
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
