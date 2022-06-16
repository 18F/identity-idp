module Idv
  module Ipp
    module FormAddressValidator
      extend ActiveSupport::Concern
      include Idv::FormAddressValidator

      included do
        validates :same_address_as_id,
                  presence: true
      end
    end
  end
end
