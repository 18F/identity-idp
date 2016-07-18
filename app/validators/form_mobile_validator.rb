module FormMobileValidator
  extend ActiveSupport::Concern

  included do
    validates_plausible_phone :mobile,
                              country_code: 'US',
                              presence: true,
                              message: :improbable_phone
  end
end
