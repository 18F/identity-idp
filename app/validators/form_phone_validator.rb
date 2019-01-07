module FormPhoneValidator
  extend ActiveSupport::Concern

  included do
    validates :phone,
              presence: true,
              phone: {
                message: :improbable_phone,
                country_specifier: ->(form) { form.international_code },
              }
    validates :international_code,
              inclusion: {
                in: PhoneNumberCapabilities::INTERNATIONAL_CODES.keys,
              }
    validate :supported_countries
  end

  private

  def supported_countries
    return if supported?
    errors.clear
    errors.add(:phone, I18n.t('errors.messages.country_not_supported'))
  end

  def supported?
    return !['JP'].include?(international_code)
  end
end
