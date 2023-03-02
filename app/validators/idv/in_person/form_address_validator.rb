module Idv
  module InPerson
    module FormAddressValidator
      extend ActiveSupport::Concern
      include Idv::FormAddressValidator
      include Idv::InPerson::FormTransliterableValidator

      included do
        validates :same_address_as_id,
                  presence: true

        transliterate :city, :address1, :address2
      end
    end
  end
end
