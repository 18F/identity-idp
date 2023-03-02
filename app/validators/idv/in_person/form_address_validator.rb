module Idv
  module InPerson
    module FormAddressValidator
      extend ActiveSupport::Concern
      include Idv::FormAddressValidator

      included do
        validates :same_address_as_id,
                  presence: true

        validates_with UspsInPersonProofing::TransliterableValidator,
                       fields: [:city, :address1, :address2]
      end
    end
  end
end
