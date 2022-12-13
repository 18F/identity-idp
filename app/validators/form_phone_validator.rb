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
  end
end
