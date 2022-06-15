module Idv
  module FormInPersonProofingAddressValidator
    extend ActiveSupport::Concern

    included do
      validates :address1,
                :city,
                :state,
                :zipcode,
                :same_address_as_id,
                presence: true
    end
  end
end
