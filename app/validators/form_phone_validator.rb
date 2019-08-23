module FormPhoneValidator
  extend ActiveSupport::Concern

  included do
    validates :phone,
              presence: true,
              phone: {
                message: :improbable_phone,
                country_specifier: ->(form) { form.international_code },
              },
              on: :create
    validates :international_code, inclusion: {
      in: PhoneNumberCapabilities::INTERNATIONAL_CODES.keys,
    }, on: :create
  end
end
