module FormPhoneValidator
  extend ActiveSupport::Concern

  included do
    validates_plausible_phone :phone,
                              presence: true,
                              message: :improbable_phone,
                              international_code: ->(form) { form.international_code }
    validates :international_code, inclusion: {
      in: PhoneNumberCapabilities::INTERNATIONAL_CODES.keys,
    }
  end
end
