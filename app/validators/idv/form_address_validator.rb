module Idv
  module FormAddressValidator
    extend ActiveSupport::Concern

    included do
      validates :state, :zipcode, presence: true

      validates_format_of :zipcode,
                          with: /\A\d{5}(-?\d{4})?\z/,
                          message: I18n.t('idv.errors.pattern_mismatch.zipcode'),
                          allow_blank: true

      validates :city, presence: true, length: { maximum: 255 }
      validates :address1, presence: true, length: { maximum: 255 }
      validates :address2, length: { maximum: 255 }
    end
  end
end
