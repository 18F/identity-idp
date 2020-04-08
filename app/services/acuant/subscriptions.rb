module Acuant
  class Subscriptions < AcuantBase
    SUBSCRIPTION_DATA = [{
      'DocumentProcessMode': 2,
      'Id': Figaro.env.acuant_assure_id_subscription_id,
      'IsActive': true,
      'IsDevelopment': Rails.env.development?,
      'IsTrial': false,
      'Name': '',
      'StorePII': false,
     }].freeze

    def call
      SUBSCRIPTION_DATA
    end
  end
end
