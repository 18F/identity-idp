module FormPhoneValidator
  extend ActiveSupport::Concern

  included do
    validates_plausible_phone :phone,
                              country_code: 'US',
                              presence: true,
                              message: :improbable_phone
  end
end
