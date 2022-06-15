module Idv
  module FormInPersonProofingAddressValidator
    extend ActiveSupport::Concern
    include FormAddressValidator

    included do
      validates :same_address_as_id,
                presence: true
    end
  end
end
