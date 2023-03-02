module Idv
  module InPerson
    module ResidentialAddressValidator
      extend ActiveSupport::Concern

      included do
        validates :residential_state, :residential_zipcode, presence: true

        validates_format_of :residential_zipcode,
                            with: /\A\d{5}(-?\d{4})?\z/,
                            message: I18n.t('idv.errors.pattern_mismatch.zipcode'),
                            allow_blank: true

        validates :residential_city, presence: true, length: { maximum: 255 }
        validates :residential_address1, presence: true, length: { maximum: 255 }
        validates :residential_address2, length: { maximum: 255 }
      end
    end
  end
end
