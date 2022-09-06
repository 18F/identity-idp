class PhoneInputComponent < BaseComponent
  attr_reader :form, :confirmed_phone, :required, :allowed_countries, :delivery_methods,
              :tag_options

  alias_method :f, :form

  def initialize(
    form:,
    confirmed_phone: true,
    allowed_countries: nil,
    delivery_methods: [:sms, :voice],
    required: false,
    **tag_options
  )
    @allowed_countries = allowed_countries
    @confirmed_phone = confirmed_phone
    @form = form
    @required = required
    @delivery_methods = delivery_methods
    @tag_options = tag_options
  end

  def supported_country_codes
    @supported_country_codes ||= begin
      codes = PhoneNumberCapabilities::INTERNATIONAL_CODES.keys
      codes &= allowed_countries if allowed_countries
      codes
    end
  end

  def translated_country_code_names
    supported_country_codes.map do |code|
      code = code.downcase
      [code, I18n.t("countries.#{code}")]
    end.to_h
  end

  def international_phone_codes
    translated_international_codes = PhoneNumberCapabilities.translated_international_codes
    supported_country_codes.
      map do |code_key|
        code_data = translated_international_codes[code_key]

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

  def strings
    {
      country_code_label: t('components.phone_input.country_code_label'),
      invalid_phone: t('errors.messages.invalid_phone_number'),
      country_constraint_usa: t('errors.messages.phone_country_constraint_usa'),
      unsupported_country: unsupported_country_string,
    }
  end

  private

  def unsupported_country_string
    case delivery_methods.sort
    when [:sms, :voice]
      t('two_factor_authentication.otp_delivery_preference.no_supported_options')
    when [:sms]
      t('two_factor_authentication.otp_delivery_preference.sms_unsupported')
    when [:voice]
      t('two_factor_authentication.otp_delivery_preference.voice_unsupported')
    end
  end

  def international_phone_code_label(code_data)
    "#{code_data['name']} +#{code_data['country_code']}"
  end

  def international_phone_codes_data(code_data)
    supports_sms = code_data['supports_sms']
    supports_sms_unconfirmed = code_data.fetch('supports_sms_unconfirmed', supports_sms)

    supports_voice = code_data['supports_voice']
    supports_voice_unconfirmed = code_data.fetch('supports_voice_unconfirmed', supports_voice)

    {
      supports_sms: supports_sms_unconfirmed || (confirmed_phone && supports_sms),
      supports_voice: supports_voice_unconfirmed || (confirmed_phone && supports_voice),
      country_code: code_data['country_code'],
      country_name: code_data['name'],
    }
  end
end
